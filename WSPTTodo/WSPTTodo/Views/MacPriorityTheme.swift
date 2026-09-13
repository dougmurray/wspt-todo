#if os(macOS)
import SwiftUI

/// Shared visual language for the macOS "Today" screen, translating the
/// Claude Design mockup (warm off-white, serif headings, one green accent)
/// into design tokens `PriorityListView` and `PriorityPlotView` both draw
/// from. macOS-only: iOS keeps its existing look, per CLAUDE.md's
/// platform-branch convention.
///
/// The mockup specifies Source Serif 4 (headings) + Work Sans (body/numeric)
/// from Google Fonts. Rather than bundle font files, headings use the
/// system serif design (New York) and body/numeric text uses the default
/// system font (San Francisco) — the same "serif heading, grotesk body"
/// pairing, built entirely from system fonts.
enum MacPriorityTheme {
    // MARK: Colors

    static let background = Color(red: 0xf1 / 255, green: 0xec / 255, blue: 0xe4 / 255)
    static let card = Color(red: 0xff / 255, green: 0xfd / 255, blue: 0xf9 / 255)
    static let subtleCard = Color(red: 0xfa / 255, green: 0xf6 / 255, blue: 0xef / 255)
    static let ink = Color(red: 0x2b / 255, green: 0x27 / 255, blue: 0x23 / 255)
    static let accent = Color(red: 0x3f / 255, green: 0x7a / 255, blue: 0x4e / 255)
    static let accentTint = Color(red: 0xee / 255, green: 0xf3 / 255, blue: 0xec / 255)
    static let accentBorder = accent.opacity(0.16)

    static func ink(_ opacity: Double) -> Color { ink.opacity(opacity) }

    // MARK: Fonts

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func label(_ size: CGFloat = 10.5, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).uppercaseSmallCaps()
    }

    // MARK: Formatting

    /// "12h 15m", "1h", "45m" — mirrors the mockup's duration display.
    static func formattedDuration(minutes: Double) -> String {
        let totalMinutes = Int(minutes.rounded())
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours == 0 { return "\(mins)m" }
        if mins == 0 { return "\(hours)h" }
        return "\(hours)h \(mins)m"
    }

    /// "15m", "1h 30m" — same as `formattedDuration`, kept as a distinct
    /// name at call sites that are specifically labeling a single task's
    /// estimate rather than a summed total.
    static func estimateLabel(minutes: Double) -> String {
        formattedDuration(minutes: minutes)
    }

    static func formattedScore(_ score: Double) -> String {
        score.isInfinite ? "∞" : String(format: "%.2f", score)
    }

    /// A plain editable number for a minutes text field — "30" rather than
    /// "30.0", but "45.5" preserved when the value isn't a whole number.
    static func plainMinutes(_ minutes: Double) -> String {
        minutes.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", minutes)
            : String(format: "%.2f", minutes)
    }
}
#endif
