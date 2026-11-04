import SwiftUI

/// Where the Calendar tab's events come from.
///
/// - `google`: talks to the Google Calendar REST API directly, after an
///   in-app OAuth sign-in (see `GoogleCalendarClient`).
/// - `system`: reads through EventKit — whatever accounts are configured in
///   the system Calendar app (iCloud, Exchange, and Google accounts added
///   under System Settings → Internet Accounts on macOS, or Settings → Apps
///   → Calendar → Calendar Accounts on iOS).
enum CalendarSource: String, CaseIterable, Identifiable, Sendable {
    case google
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .google: "Google Calendar"
        #if os(macOS)
        case .system: "macOS Calendar"
        #else
        case .system: "iPhone Calendar"
        #endif
        }
    }
}

/// A plain RGB triple — `Sendable`, unlike `Color`/`CGColor` — so events can
/// cross from the Google client actor to the main actor.
struct RGBColor: Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    static let fallback = RGBColor(red: 0x3f / 255, green: 0x7a / 255, blue: 0x4e / 255)

    /// Parses "#RRGGBB" (Google's `backgroundColor` format).
    init?(hex: String?) {
        guard let hex else { return nil }
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        red = Double((value >> 16) & 0xff) / 255
        green = Double((value >> 8) & 0xff) / 255
        blue = Double(value & 0xff) / 255
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(cgColor: CGColor?) {
        guard
            let cgColor,
            let srgb = cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
            let components = srgb.components, components.count >= 3
        else {
            self = .fallback
            return
        }
        self.init(red: components[0], green: components[1], blue: components[2])
    }

    var color: Color { Color(red: red, green: green, blue: blue) }
}

/// One calendar (a Google calendar-list entry or an `EKCalendar`), used for
/// the show/hide menu.
struct CalendarInfo: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let color: RGBColor
}

/// A source-agnostic event. All-day events use local-midnight `start` and an
/// exclusive `end` (the next midnight after the last day), matching both
/// Google's and EventKit's conventions.
struct CalendarEvent: Identifiable, Hashable, Sendable {
    let id: String
    let calendarID: String
    let calendarTitle: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let color: RGBColor
    /// A link back to the event in its home app (Google's `htmlLink`).
    let url: URL?

    /// Whether any part of this event falls on the day starting at `dayStart`.
    func overlaps(dayStart: Date, dayEnd: Date) -> Bool {
        if start == end { return start >= dayStart && start < dayEnd }
        return start < dayEnd && end > dayStart
    }
}

/// An open task with a due date, drawn on the calendar alongside events so
/// deadlines are visible in context.
struct DueTaskMarker: Identifiable, Hashable {
    let id: UUID
    let title: String
    let dueDate: Date
}
