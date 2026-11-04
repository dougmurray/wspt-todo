import SwiftUI

#if os(macOS)
/// The tokens `CalendarTabView` draws from. On macOS the calendar sits in
/// the warm-cream "Today" window, so it uses `MacPriorityTheme` as-is.
typealias CalendarTheme = MacPriorityTheme
#else
/// The tokens `CalendarTabView` draws from, mirroring `MacPriorityTheme`'s
/// member names so the shared calendar views compile against either. On iOS
/// the calendar replaces the queue in landscape, so it follows the queue's
/// fixed dark look (`IOSPriorityTheme`): near-black cards, white ink, the
/// same green accent, and system sans headings instead of the Mac serif.
enum CalendarTheme {
    static let background = IOSPriorityTheme.background
    static let card = Color(white: 0.07)
    static let subtleCard = Color(white: 0.12)
    static let ink = Color.white
    static let accent = IOSPriorityTheme.accent
    static let accentTint = IOSPriorityTheme.accent.opacity(0.22)
    static let accentBorder = IOSPriorityTheme.cancelAccent.opacity(0.45)
    /// Accent used as text on `accentTint` — the lighter green, since
    /// `accent` itself is too dark to read on a dark tint.
    static let accentInk = IOSPriorityTheme.cancelAccent

    static func ink(_ opacity: Double) -> Color { ink.opacity(opacity) }

    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func label(_ size: CGFloat = 10.5, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).uppercaseSmallCaps()
    }
}
#endif
