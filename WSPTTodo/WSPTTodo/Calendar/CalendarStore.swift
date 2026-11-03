#if os(macOS)
import SwiftUI
import EventKit
import AuthenticationServices

/// Owns the Calendar tab's connection state and the events for whatever
/// date range the tab is currently showing. Source-agnostic: the views only
/// ever see `CalendarInfo` / `CalendarEvent`.
@MainActor
@Observable
final class CalendarStore {
    private(set) var source: CalendarSource?
    private(set) var calendars: [CalendarInfo] = []
    private(set) var events: [CalendarEvent] = []
    private(set) var isLoading = false
    private(set) var isConnecting = false
    var errorMessage: String?

    /// User-entered Google OAuth client ID, used only when the Info.plist's
    /// `GoogleOAuthClientID` is empty.
    var enteredGoogleClientID: String {
        didSet { defaults.set(enteredGoogleClientID, forKey: Keys.clientID) }
    }

    private(set) var hiddenCalendarIDs: Set<String> = []

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let google = GoogleCalendarClient()
    @ObservationIgnored private let eventStore = EKEventStore()
    @ObservationIgnored private var currentRange: DateInterval?
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var eventStoreObserver: NSObjectProtocol?

    private enum Keys {
        static let source = "calendar.source"
        static let clientID = "calendar.googleClientID"
        static func hidden(_ source: CalendarSource) -> String { "calendar.hidden.\(source.rawValue)" }
    }

    init() {
        enteredGoogleClientID = defaults.string(forKey: Keys.clientID) ?? ""
        if let raw = defaults.string(forKey: Keys.source), let saved = CalendarSource(rawValue: raw) {
            setSource(saved)
        }
    }

    /// The client ID baked into Info.plist (from `project.yml`), if any.
    var bundledGoogleClientID: String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String)?
            .trimmingCharacters(in: .whitespaces)
        return value?.isEmpty == false ? value : nil
    }

    var effectiveGoogleClientID: String? {
        if let bundledGoogleClientID { return bundledGoogleClientID }
        let entered = enteredGoogleClientID.trimmingCharacters(in: .whitespaces)
        return entered.isEmpty ? nil : entered
    }

    var visibleEvents: [CalendarEvent] {
        events.filter { !hiddenCalendarIDs.contains($0.calendarID) }
    }

    // MARK: - Connecting

    func connectGoogle(using webAuth: WebAuthenticationSession) async {
        guard let clientID = effectiveGoogleClientID else {
            errorMessage = GoogleCalendarClient.ClientError.notConfigured.localizedDescription
            return
        }
        isConnecting = true
        defer { isConnecting = false }
        errorMessage = nil
        let pending = GoogleCalendarClient.makeAuthorization(clientID: clientID)
        do {
            let callback = try await webAuth.authenticate(
                using: pending.url,
                callbackURLScheme: pending.callbackScheme,
                preferredBrowserSession: .ephemeral
            )
            try await google.completeAuthorization(pending, callbackURL: callback)
            setSource(.google)
            await reload()
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // User closed the sign-in sheet — not an error worth showing.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connectSystemCalendar() async {
        isConnecting = true
        defer { isConnecting = false }
        errorMessage = nil
        let granted: Bool = await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        guard granted else {
            errorMessage = "Calendar access was denied. Enable it for WSPT Todo in System Settings → Privacy & Security → Calendars."
            return
        }
        setSource(.system)
        await reload()
    }

    func disconnect() async {
        if source == .google { await google.signOut() }
        setSource(nil)
    }

    private func setSource(_ newSource: CalendarSource?) {
        source = newSource
        calendars = []
        events = []
        currentRange = nil
        defaults.set(newSource?.rawValue, forKey: Keys.source)
        hiddenCalendarIDs = newSource.map { Set(defaults.stringArray(forKey: Keys.hidden($0)) ?? []) } ?? []

        if let eventStoreObserver {
            NotificationCenter.default.removeObserver(eventStoreObserver)
            self.eventStoreObserver = nil
        }
        if newSource == .system {
            // Pick up edits made in Calendar.app (or synced from Google) live.
            eventStoreObserver = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged,
                object: eventStore,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    Task { await self.reload() }
                }
            }
        }
    }

    // MARK: - Calendars

    func toggleVisibility(of calendar: CalendarInfo) {
        guard let source else { return }
        if hiddenCalendarIDs.contains(calendar.id) {
            hiddenCalendarIDs.remove(calendar.id)
        } else {
            hiddenCalendarIDs.insert(calendar.id)
        }
        defaults.set(Array(hiddenCalendarIDs), forKey: Keys.hidden(source))
    }

    // MARK: - Loading

    func load(range: DateInterval) async {
        currentRange = range
        await reload()
    }

    func reload() async {
        guard let source, let range = currentRange else { return }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer { if generation == loadGeneration { isLoading = false } }

        do {
            let (fetchedCalendars, fetchedEvents): ([CalendarInfo], [CalendarEvent])
            switch source {
            case .google:
                (fetchedCalendars, fetchedEvents) = try await loadGoogle(range: range)
            case .system:
                (fetchedCalendars, fetchedEvents) = try loadSystem(range: range)
            }
            // A newer range was requested while this one was in flight.
            guard generation == loadGeneration, source == self.source else { return }
            calendars = fetchedCalendars
            events = fetchedEvents
            errorMessage = nil
        } catch GoogleCalendarClient.ClientError.notSignedIn {
            setSource(nil)
            errorMessage = "Your Google sign-in expired. Connect again to keep seeing your calendar."
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadGoogle(range: DateInterval) async throws -> ([CalendarInfo], [CalendarEvent]) {
        let calendars = try await google.calendars()
        let google = self.google
        let events = try await withThrowingTaskGroup(of: [CalendarEvent].self) { group in
            for calendar in calendars {
                group.addTask {
                    try await google.events(in: calendar, from: range.start, to: range.end)
                }
            }
            var all: [CalendarEvent] = []
            for try await batch in group { all += batch }
            return all
        }
        return (calendars, events)
    }

    private func loadSystem(range: DateInterval) throws -> ([CalendarInfo], [CalendarEvent]) {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            setSource(nil)
            throw NSError(domain: "WSPTTodo.Calendar", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Calendar access is no longer granted. Connect again to continue.",
            ])
        }
        let ekCalendars = eventStore.calendars(for: .event)
        let calendars = ekCalendars.map {
            CalendarInfo(id: $0.calendarIdentifier, title: $0.title, color: RGBColor(cgColor: $0.cgColor))
        }
        let predicate = eventStore.predicateForEvents(withStart: range.start, end: range.end, calendars: ekCalendars)
        let events = eventStore.events(matching: predicate).map { event in
            CalendarEvent(
                id: "\(event.calendarItemIdentifier)/\(event.startDate.timeIntervalSince1970)",
                calendarID: event.calendar.calendarIdentifier,
                calendarTitle: event.calendar.title,
                title: event.title?.isEmpty == false ? event.title! : "(No title)",
                start: event.startDate,
                end: max(event.endDate, event.startDate),
                isAllDay: event.isAllDay,
                location: event.location,
                color: RGBColor(cgColor: event.calendar.cgColor),
                url: nil
            )
        }
        return (calendars, events)
    }
}
#endif
