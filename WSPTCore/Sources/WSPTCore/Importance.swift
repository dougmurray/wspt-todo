import Foundation

/// A todo item's importance, on the 1–5 labeled scale from docs/overvall-plan.md.
///
/// Deliberately a plain linear 1–5 scale (Trivial…Critical), not the
/// Fibonacci-style 1/2/3/5/8 spread explored in python-logic/tester.ipynb —
/// that variant was superseded.
public enum Importance: Int, CaseIterable, Codable, Comparable, Sendable {
    case trivial = 1
    case low = 2
    case normal = 3
    case high = 4
    case critical = 5

    /// Human-readable label, matching the `<select>` options and
    /// `importanceLabel()` in docs/wspt-todo.html.
    public var label: String {
        switch self {
        case .trivial: return "Trivial"
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    public static func < (lhs: Importance, rhs: Importance) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
