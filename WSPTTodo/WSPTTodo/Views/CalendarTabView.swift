#if os(macOS)
import SwiftUI
import AuthenticationServices

/// Month or week layout for the Calendar tab.
enum CalendarDisplayMode: String {
    case month
    case week
}

/// The macOS "Calendar" tab: connect a calendar (Google first, or anything
/// in macOS Calendar via EventKit), then browse it by month or week. Open
/// tasks with due dates are overlaid on their due day.
struct CalendarTabView: View {
    let store: CalendarStore
    let dueTasks: [DueTaskMarker]

    @AppStorage("calendar.displayMode") private var displayMode: CalendarDisplayMode = .month
    @State private var anchorDate: Date = .now

    private var calendar: Calendar { .current }

    var body: some View {
        if store.source == nil {
            ConnectCalendarView(store: store)
        } else {
            VStack(spacing: 14) {
                toolbar
                if let error = store.errorMessage {
                    ErrorBanner(message: error) { store.errorMessage = nil }
                }
                Group {
                    switch displayMode {
                    case .month:
                        MonthGridView(
                            days: monthDays,
                            displayedMonth: anchorDate,
                            events: store.visibleEvents,
                            dueTasks: dueTasks,
                            onOpenWeek: { day in
                                anchorDate = day
                                displayMode = .week
                            }
                        )
                    case .week:
                        WeekGridView(days: weekDays, events: store.visibleEvents, dueTasks: dueTasks)
                    }
                }
                .background(MacPriorityTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MacPriorityTheme.ink(0.08)))
            }
            .task(id: LoadKey(range: visibleRange, source: store.source)) {
                await store.load(range: visibleRange)
            }
        }
    }

    private struct LoadKey: Hashable {
        let range: DateInterval
        let source: CalendarSource?
    }

    // MARK: Date math

    /// The 42 days (6 weeks) of the grid containing `anchorDate`'s month.
    private var monthDays: [Date] {
        let monthStart = calendar.dateInterval(of: .month, for: anchorDate)!.start
        let gridStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)!.start
        return (0..<42).map { calendar.date(byAdding: .day, value: $0, to: gridStart)! }
    }

    private var weekDays: [Date] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: anchorDate)!.start
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: weekStart)! }
    }

    private var visibleRange: DateInterval {
        let days = displayMode == .month ? monthDays : weekDays
        let end = calendar.date(byAdding: .day, value: 1, to: days.last!)!
        return DateInterval(start: days.first!, end: end)
    }

    private func step(_ direction: Int) {
        let unit: Calendar.Component = displayMode == .month ? .month : .weekOfYear
        anchorDate = calendar.date(byAdding: unit, value: direction, to: anchorDate) ?? anchorDate
    }

    private var title: String {
        if displayMode == .month {
            return anchorDate.formatted(.dateTime.month(.wide).year())
        }
        let days = weekDays
        let first = days.first!, last = days.last!
        if calendar.isDate(first, equalTo: last, toGranularity: .month) {
            return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.day())), \(last.formatted(.dateTime.year()))"
        }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                iconButton("chevron.left", help: "Previous") { step(-1) }
                iconButton("chevron.right", help: "Next") { step(1) }
            }
            Text(title)
                .font(MacPriorityTheme.serif(20))
                .foregroundStyle(MacPriorityTheme.ink)
            Button("Today") { anchorDate = .now }
                .buttonStyle(.plain)
                .font(MacPriorityTheme.sans(12, weight: .medium))
                .foregroundStyle(MacPriorityTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MacPriorityTheme.accentTint)
                .clipShape(Capsule())
            if store.isLoading {
                ProgressView().controlSize(.small)
            }
            Spacer()
            modePicker
            calendarsMenu
        }
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MacPriorityTheme.ink(0.7))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var modePicker: some View {
        HStack(spacing: 2) {
            modeButton("Month", .month)
            modeButton("Week", .week)
        }
        .padding(3)
        .background(MacPriorityTheme.subtleCard)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(MacPriorityTheme.ink(0.1)))
    }

    private func modeButton(_ label: String, _ mode: CalendarDisplayMode) -> some View {
        let isSelected = displayMode == mode
        return Button { displayMode = mode } label: {
            Text(label)
                .font(MacPriorityTheme.sans(12, weight: .medium))
                .foregroundStyle(isSelected ? MacPriorityTheme.ink : MacPriorityTheme.ink(0.55))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? MacPriorityTheme.card : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var calendarsMenu: some View {
        Menu {
            Section(store.source?.displayName ?? "") {
                ForEach(store.calendars) { cal in
                    Toggle(isOn: Binding(
                        get: { !store.hiddenCalendarIDs.contains(cal.id) },
                        set: { _ in store.toggleVisibility(of: cal) }
                    )) {
                        Text(cal.title)
                    }
                }
            }
            Divider()
            Button("Refresh") { Task { await store.reload() } }
                .keyboardShortcut("r")
            Button("Disconnect \(store.source?.displayName ?? "Calendar")…") {
                Task { await store.disconnect() }
            }
        } label: {
            Image(systemName: "calendar.badge.checkmark")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Calendars")
    }
}

// MARK: - Connect screen

private struct ConnectCalendarView: View {
    let store: CalendarStore
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Environment(\.openURL) private var openURL
    @State private var clientIDDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connect a calendar")
                        .font(MacPriorityTheme.serif(22))
                        .foregroundStyle(MacPriorityTheme.ink)
                    Text("See your schedule next to your queue. Access is read-only — WSPT Todo never changes your events.")
                        .font(MacPriorityTheme.sans(13))
                        .foregroundStyle(MacPriorityTheme.ink(0.55))
                }

                if let error = store.errorMessage {
                    ErrorBanner(message: error) { store.errorMessage = nil }
                }

                googleCard
                systemCard
            }
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
        .onAppear { clientIDDraft = store.enteredGoogleClientID }
    }

    private var googleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(MacPriorityTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Calendar")
                        .font(MacPriorityTheme.sans(15, weight: .semibold))
                    Text("Sign in with your Google account. Recommended.")
                        .font(MacPriorityTheme.sans(12))
                        .foregroundStyle(MacPriorityTheme.ink(0.55))
                }
                Spacer()
            }

            if store.bundledGoogleClientID == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OAuth client ID")
                        .font(MacPriorityTheme.label())
                        .foregroundStyle(MacPriorityTheme.ink(0.5))
                    TextField("1234567890-abc….apps.googleusercontent.com", text: $clientIDDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(MacPriorityTheme.sans(12))
                        .onChange(of: clientIDDraft) { _, newValue in
                            store.enteredGoogleClientID = newValue
                        }
                    Text("Create an **iOS** OAuth client in Google Cloud Console with bundle ID `com.douglassmurray.wspttodo`, and enable the Google Calendar API for that project. Or set `GoogleOAuthClientID` in project.yml to skip this field.")
                        .font(MacPriorityTheme.sans(11))
                        .foregroundStyle(MacPriorityTheme.ink(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Google Cloud Console") {
                        openURL(URL(string: "https://console.cloud.google.com/apis/credentials")!)
                    }
                    .buttonStyle(.link)
                    .font(MacPriorityTheme.sans(11))
                }
            }

            Button {
                Task { await store.connectGoogle(using: webAuthenticationSession) }
            } label: {
                Text("Sign in with Google")
                    .font(MacPriorityTheme.sans(13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(MacPriorityTheme.accent.opacity(store.effectiveGoogleClientID == nil ? 0.4 : 1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(store.effectiveGoogleClientID == nil || store.isConnecting)
        }
        .padding(18)
        .background(MacPriorityTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MacPriorityTheme.accentBorder))
    }

    private var systemCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 20))
                    .foregroundStyle(MacPriorityTheme.ink(0.6))
                VStack(alignment: .leading, spacing: 2) {
                    Text("macOS Calendar")
                        .font(MacPriorityTheme.sans(15, weight: .semibold))
                    Text("Use the accounts already in the Calendar app — iCloud, Exchange, or a Google account added in System Settings → Internet Accounts.")
                        .font(MacPriorityTheme.sans(12))
                        .foregroundStyle(MacPriorityTheme.ink(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            Button {
                Task { await store.connectSystemCalendar() }
            } label: {
                Text("Allow Calendar Access")
                    .font(MacPriorityTheme.sans(13, weight: .medium))
                    .foregroundStyle(MacPriorityTheme.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(MacPriorityTheme.subtleCard)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MacPriorityTheme.ink(0.12)))
            }
            .buttonStyle(.plain)
            .disabled(store.isConnecting)
        }
        .padding(18)
        .background(MacPriorityTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MacPriorityTheme.ink(0.08)))
    }
}

private struct ErrorBanner: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(MacPriorityTheme.sans(12))
                .foregroundStyle(MacPriorityTheme.ink(0.8))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(MacPriorityTheme.ink(0.4))
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Shared pieces

private func eventsOn(_ day: Date, in events: [CalendarEvent]) -> [CalendarEvent] {
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: day)
    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
    return events
        .filter { $0.overlaps(dayStart: dayStart, dayEnd: dayEnd) }
        .sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.title < rhs.title
        }
}

private func tasksDue(on day: Date, in tasks: [DueTaskMarker]) -> [DueTaskMarker] {
    tasks.filter { Calendar.current.isDate($0.dueDate, inSameDayAs: day) }
}

private func shortTime(_ date: Date) -> String {
    date.formatted(.dateTime.hour(.defaultDigits(amPM: .narrow)).minute())
}

private func timeRangeLabel(_ event: CalendarEvent) -> String {
    let calendar = Calendar.current
    if event.isAllDay {
        let lastDay = calendar.date(byAdding: .second, value: -1, to: event.end) ?? event.end
        if calendar.isDate(event.start, inSameDayAs: lastDay) {
            return "All day · \(event.start.formatted(.dateTime.weekday(.wide).month().day()))"
        }
        return "All day · \(event.start.formatted(.dateTime.month().day())) – \(lastDay.formatted(.dateTime.month().day()))"
    }
    if calendar.isDate(event.start, inSameDayAs: event.end) {
        return "\(event.start.formatted(.dateTime.weekday(.wide).month().day())) · \(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))"
    }
    return "\(event.start.formatted(date: .abbreviated, time: .shortened)) – \(event.end.formatted(date: .abbreviated, time: .shortened))"
}

private struct EventDetailPopover: View {
    let event: CalendarEvent
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle().fill(event.color.color).frame(width: 9, height: 9)
                Text(event.title)
                    .font(MacPriorityTheme.sans(14, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label(timeRangeLabel(event), systemImage: "clock")
            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label(event.calendarTitle, systemImage: "calendar")
            if let url = event.url {
                Button("Open in Google Calendar") { openURL(url) }
                    .buttonStyle(.link)
            }
        }
        .font(MacPriorityTheme.sans(12))
        .foregroundStyle(MacPriorityTheme.ink(0.8))
        .padding(14)
        .frame(width: 280, alignment: .leading)
    }
}

/// One compact line in a month cell or the week view's all-day row.
private struct EventChip: View {
    let event: CalendarEvent
    var showTime = true
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack(spacing: 4) {
                if event.isAllDay {
                    Text(event.title)
                        .foregroundStyle(.white)
                } else {
                    Circle().fill(event.color.color).frame(width: 6, height: 6)
                    if showTime {
                        Text(shortTime(event.start))
                            .foregroundStyle(MacPriorityTheme.ink(0.5))
                    }
                    Text(event.title)
                        .foregroundStyle(MacPriorityTheme.ink(0.85))
                }
                Spacer(minLength: 0)
            }
            .font(MacPriorityTheme.sans(10.5))
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(height: 16)
            .background(event.isAllDay ? event.color.color.opacity(0.9) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDetail, arrowEdge: .trailing) {
            EventDetailPopover(event: event)
        }
    }
}

private struct TaskChip: View {
    let task: DueTaskMarker

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checklist")
                .font(.system(size: 9, weight: .semibold))
            Text(task.title)
            Spacer(minLength: 0)
        }
        .font(MacPriorityTheme.sans(10.5, weight: .medium))
        .foregroundStyle(MacPriorityTheme.accent)
        .lineLimit(1)
        .padding(.horizontal, 4)
        .frame(height: 16)
        .background(MacPriorityTheme.accentTint)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(MacPriorityTheme.accentBorder))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help("Task due: \(task.title)")
    }
}

private struct WeekdayHeader: View {
    var body: some View {
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols
        let ordered = (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
        HStack(spacing: 0) {
            ForEach(ordered, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(MacPriorityTheme.sans(10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(MacPriorityTheme.ink(0.45))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Month

private struct MonthGridView: View {
    let days: [Date]
    let displayedMonth: Date
    let events: [CalendarEvent]
    let dueTasks: [DueTaskMarker]
    var onOpenWeek: (Date) -> Void

    var body: some View {
        VStack(spacing: 0) {
            WeekdayHeader()
            Divider().overlay(MacPriorityTheme.ink(0.06))
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { column in
                            let day = days[row * 7 + column]
                            MonthDayCell(
                                day: day,
                                isInMonth: Calendar.current.isDate(day, equalTo: displayedMonth, toGranularity: .month),
                                events: eventsOn(day, in: events),
                                tasks: tasksDue(on: day, in: dueTasks),
                                onOpenWeek: { onOpenWeek(day) }
                            )
                            if column < 6 { Divider().overlay(MacPriorityTheme.ink(0.04)) }
                        }
                    }
                    if row < 5 { Divider().overlay(MacPriorityTheme.ink(0.06)) }
                }
            }
        }
    }
}

private struct MonthDayCell: View {
    let day: Date
    let isInMonth: Bool
    let events: [CalendarEvent]
    let tasks: [DueTaskMarker]
    var onOpenWeek: () -> Void

    @State private var showAll = false

    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var itemCount: Int { events.count + tasks.count }

    var body: some View {
        GeometryReader { proxy in
            let capacity = max(0, Int((proxy.size.height - 26) / 17))
            let needsMore = itemCount > capacity
            let shown = needsMore ? max(0, capacity - 1) : capacity
            let shownTasks = Array(tasks.prefix(shown))
            let shownEvents = Array(events.prefix(max(0, shown - shownTasks.count)))

            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(day.formatted(.dateTime.day()))
                        .font(MacPriorityTheme.sans(11.5, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? .white : MacPriorityTheme.ink(isInMonth ? 0.8 : 0.3))
                        .frame(minWidth: 20, minHeight: 20)
                        .background(isToday ? MacPriorityTheme.accent : Color.clear)
                        .clipShape(Circle())
                    Spacer()
                }
                .padding(.bottom, 2)

                ForEach(shownTasks) { TaskChip(task: $0) }
                ForEach(shownEvents) { EventChip(event: $0) }
                if needsMore {
                    Button { showAll = true } label: {
                        Text("+\(itemCount - shownTasks.count - shownEvents.count) more")
                            .font(MacPriorityTheme.sans(10, weight: .medium))
                            .foregroundStyle(MacPriorityTheme.ink(0.5))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showAll, arrowEdge: .trailing) { dayList }
                }
                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .opacity(isInMonth ? 1 : 0.55)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isInMonth ? Color.clear : MacPriorityTheme.subtleCard.opacity(0.6))
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onOpenWeek)
        .help("Double-click to open this week")
    }

    private var dayList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(MacPriorityTheme.sans(13, weight: .semibold))
                .padding(.bottom, 4)
            ForEach(tasks) { TaskChip(task: $0) }
            ForEach(events) { EventChip(event: $0) }
        }
        .padding(12)
        .frame(width: 240, alignment: .leading)
    }
}

// MARK: - Week

private struct WeekGridView: View {
    let days: [Date]
    let events: [CalendarEvent]
    let dueTasks: [DueTaskMarker]

    private let hourHeight: CGFloat = 46
    private let gutter: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            dayHeader
            Divider().overlay(MacPriorityTheme.ink(0.06))
            allDayRow
            Divider().overlay(MacPriorityTheme.ink(0.1))
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        hourLines
                        HStack(spacing: 0) {
                            Color.clear.frame(width: gutter)
                            ForEach(days, id: \.self) { day in
                                DayColumn(day: day, events: timedEvents(on: day), hourHeight: hourHeight)
                                    .frame(maxWidth: .infinity)
                                    .overlay(alignment: .leading) {
                                        Rectangle().fill(MacPriorityTheme.ink(0.05)).frame(width: 1)
                                    }
                            }
                        }
                    }
                    .frame(height: hourHeight * 24)
                }
                .onAppear { proxy.scrollTo(7, anchor: .top) }
            }
        }
    }

    private func timedEvents(on day: Date) -> [CalendarEvent] {
        eventsOn(day, in: events).filter { !$0.isAllDay }
    }

    private var dayHeader: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutter)
            ForEach(days, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                HStack(spacing: 5) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(MacPriorityTheme.sans(10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(MacPriorityTheme.ink(0.45))
                    Text(day.formatted(.dateTime.day()))
                        .font(MacPriorityTheme.sans(13, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? .white : MacPriorityTheme.ink(0.8))
                        .frame(minWidth: 22, minHeight: 22)
                        .background(isToday ? MacPriorityTheme.accent : Color.clear)
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }

    private var allDayRow: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("all-day")
                .font(MacPriorityTheme.sans(9.5))
                .foregroundStyle(MacPriorityTheme.ink(0.4))
                .frame(width: gutter - 6, alignment: .trailing)
                .padding(.trailing, 6)
                .padding(.top, 2)
            ForEach(days, id: \.self) { day in
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(tasksDue(on: day, in: dueTasks)) { TaskChip(task: $0) }
                    ForEach(eventsOn(day, in: events).filter(\.isAllDay)) {
                        EventChip(event: $0)
                    }
                }
                .padding(3)
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .topLeading)
            }
        }
        .padding(.vertical, 2)
    }

    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(hourLabel(hour))
                        .font(MacPriorityTheme.sans(9.5))
                        .foregroundStyle(MacPriorityTheme.ink(0.4))
                        .frame(width: gutter - 8, alignment: .trailing)
                        .padding(.trailing, 8)
                        .offset(y: -6)
                        .opacity(hour == 0 ? 0 : 1)
                    Rectangle().fill(MacPriorityTheme.ink(0.06)).frame(height: 1)
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)!
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }
}

/// One day's timed events, positioned by time, with overlapping events
/// split side by side.
private struct DayColumn: View {
    let day: Date
    let events: [CalendarEvent]
    let hourHeight: CGFloat

    private struct Placement: Identifiable {
        let event: CalendarEvent
        let top: CGFloat
        let height: CGFloat
        let column: Int
        let columnCount: Int
        var id: String { event.id }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                ForEach(placements) { placement in
                    let columnWidth = (width - 4) / CGFloat(placement.columnCount)
                    EventBlock(event: placement.event)
                        .frame(width: max(columnWidth - 2, 4), height: placement.height)
                        .offset(x: 2 + CGFloat(placement.column) * columnWidth, y: placement.top)
                }
                if Calendar.current.isDateInToday(day) {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let minutes = context.date.timeIntervalSince(Calendar.current.startOfDay(for: day)) / 60
                        HStack(spacing: 0) {
                            Circle().fill(Color.red).frame(width: 7, height: 7)
                            Rectangle().fill(Color.red).frame(height: 1.5)
                        }
                        .offset(x: -3, y: CGFloat(minutes) / 60 * hourHeight - 3.5)
                    }
                }
            }
        }
    }

    /// Greedy column assignment within clusters of transitively-overlapping
    /// events (the same approach most calendar apps use).
    private var placements: [Placement] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let minHeight = hourHeight / 3

        struct Slot { let event: CalendarEvent; let start: Date; let end: Date; var column = 0 }
        let slots = events
            .map { Slot(event: $0, start: max($0.start, dayStart), end: min(max($0.end, $0.start.addingTimeInterval(15 * 60)), dayEnd)) }
            .sorted { ($0.start, $0.end) < ($1.start, $1.end) }

        var result: [Placement] = []
        var cluster: [Slot] = []
        var clusterEnd = Date.distantPast
        var columnEnds: [Date] = []

        func flush() {
            let count = max(columnEnds.count, 1)
            for slot in cluster {
                let top = CGFloat(slot.start.timeIntervalSince(dayStart) / 3600) * hourHeight
                let height = max(CGFloat(slot.end.timeIntervalSince(slot.start) / 3600) * hourHeight, minHeight)
                result.append(Placement(event: slot.event, top: top, height: height, column: slot.column, columnCount: count))
            }
            cluster = []
            columnEnds = []
        }

        for var slot in slots {
            if slot.start >= clusterEnd { flush() }
            if let free = columnEnds.firstIndex(where: { $0 <= slot.start }) {
                slot.column = free
                columnEnds[free] = slot.end
            } else {
                slot.column = columnEnds.count
                columnEnds.append(slot.end)
            }
            cluster.append(slot)
            clusterEnd = max(clusterEnd, slot.end)
        }
        flush()
        return result
    }
}

private struct EventBlock: View {
    let event: CalendarEvent
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack(spacing: 0) {
                Rectangle().fill(event.color.color).frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(MacPriorityTheme.sans(10.5, weight: .semibold))
                        .foregroundStyle(MacPriorityTheme.ink(0.9))
                    Text(shortTime(event.start))
                        .font(MacPriorityTheme.sans(9.5))
                        .foregroundStyle(MacPriorityTheme.ink(0.55))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .background(event.color.color.opacity(0.16))
            .background(MacPriorityTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDetail, arrowEdge: .trailing) {
            EventDetailPopover(event: event)
        }
    }
}
#endif
