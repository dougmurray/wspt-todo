#if os(iOS)
import SwiftUI
import WSPTCore

/// Shared visual language for the iOS queue screen, translating the Claude
/// Design mockup ("WSPT To Do App UI" project, turn 6 — "iOS, stacked color
/// bars, intensity falling with score") into design tokens `ContentView`,
/// `TodoRow`, and `AddTodoForm` all draw from. iOS-only: macOS keeps its own
/// warm-cream look in `MacPriorityTheme`, per CLAUDE.md's platform-branch
/// convention.
///
/// The mockup is a fixed dark theme (black background, white text, one
/// green accent) rather than one that adapts to Light Mode — every row,
/// pill, and button below is drawn from literal mockup colors, not
/// semantic/adaptive ones.
enum IOSPriorityTheme {
    // MARK: Colors

    static let background = Color.black

    /// The brightest step of the row color ramp (`#45875a`) — also the
    /// header background and the one accent used for buttons/pills/cursor.
    static let accent = Color(red: 0x45 / 255, green: 0x87 / 255, blue: 0x5a / 255)
    /// The mockup's "Cancel" text color on the New Task screen — a lighter
    /// green than `accent`, legible on black without filling like a button.
    static let cancelAccent = Color(red: 0x6a / 255, green: 0xa8 / 255, blue: 0x7c / 255)
    /// The "slots in at #N" preview card background (`#396f47`) — the
    /// ramp's second step, used regardless of where the task would
    /// actually land so the preview always reads as "a band", not a rank.
    static let previewCard = Color(red: 0x39 / 255, green: 0x6f / 255, blue: 0x47 / 255)

    private static let rampStart = (r: Double(0x45), g: Double(0x87), b: Double(0x5a))
    private static let rampEnd = (r: Double(0x1b), g: Double(0x35), b: Double(0x24))

    /// The row background for an open task at `index` (0 = top of the
    /// queue) out of `total` open tasks — interpolated linearly from the
    /// mockup's brightest step (`#45875a`) to its darkest (`#1b3524`), so
    /// intensity falls smoothly with rank regardless of list length.
    static func rowColor(atIndex index: Int, of total: Int) -> Color {
        guard total > 1 else { return accent }
        let t = min(max(Double(index) / Double(total - 1), 0), 1)
        let r = rampStart.r + (rampEnd.r - rampStart.r) * t
        let g = rampStart.g + (rampEnd.g - rampStart.g) * t
        let b = rampStart.b + (rampEnd.b - rampStart.b) * t
        return Color(red: r / 255, green: g / 255, blue: b / 255)
    }

    /// Opacity for a completed task's strikethrough title at `index` (0 =
    /// most recently completed) in the "Done" section — mirrors the
    /// mockup's fading stack (`.26`, `.22`, `.18`, …), floored so old items
    /// stay faintly legible rather than disappearing.
    static func doneOpacity(atIndex index: Int) -> Double {
        max(0.26 - Double(index) * 0.04, 0.1)
    }

    // MARK: Formatting

    static func formattedScore(_ score: Double) -> String {
        score.isInfinite ? "∞" : String(format: "%.2f", score)
    }

    /// "15 min", "120 min" — the mockup always uses the literal word "min",
    /// not pluralized, unlike macOS's compact "15m"/"1h 30m" style.
    static func minutesLabel(_ minutes: Double) -> String {
        let formatted = minutes.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", minutes)
            : String(format: "%.2f", minutes)
        return "\(formatted) min"
    }

    /// "0.75h", "2h" — the compact hours form used in the New Task screen's
    /// formula readout ("5 ÷ (2 × 0.75h) = 3.33").
    static func hoursLabel(_ minutes: Double) -> String {
        let hours = minutes / 60
        if hours == hours.rounded() {
            return String(format: "%.0fh", hours)
        }
        var formatted = String(format: "%.2f", hours)
        while formatted.hasSuffix("0") { formatted.removeLast() }
        if formatted.hasSuffix(".") { formatted.removeLast() }
        return "\(formatted)h"
    }
}
#endif
