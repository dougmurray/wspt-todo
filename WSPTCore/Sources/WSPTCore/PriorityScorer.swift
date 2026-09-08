import Foundation

/// Weighted Shortest Processing Time scoring and ranking.
///
/// Formula and tie-break rule per docs/overvall-plan.md:
///   priority = importance / (2 × estimated_time), sorted descending;
///   ties broken by creation timestamp, oldest first.
///
/// Mirrors the reference prototypes:
///   - docs/wspt-todo.html `computeScore()` / `render()` (lines ~300–318)
///   - python-logic/python-logic.py's `items.sort(...)` (generalized here to
///     the 2× divisor and open/done split the HTML prototype adds)
public enum PriorityScorer {

    /// The WSPT priority score for a single item's importance/time pair.
    /// A non-positive estimated time is treated as "instant" and scores
    /// `.infinity`, matching the guard in docs/wspt-todo.html:300-303.
    public static func score(importance: Importance, estimatedMinutes: Double) -> Double {
        guard estimatedMinutes > 0 else { return .infinity }
        return Double(importance.rawValue) / (2.0 * estimatedMinutes)
    }

    /// Convenience overload for a single `TodoItem`.
    public static func score(for item: TodoItem) -> Double {
        score(importance: item.importance, estimatedMinutes: item.estimatedMinutes)
    }

    /// Ranks items for display: open items first (highest score first, ties
    /// broken by oldest `createdAt` first), followed by done items (oldest
    /// `createdAt` first). Always recomputes from scratch — call this after
    /// every insert/edit/toggle/delete rather than trying to update in place.
    public static func rank(_ items: [TodoItem]) -> [TodoItem] {
        let open = items.filter { !$0.isDone }
        let done = items.filter { $0.isDone }

        let sortedOpen = open.sorted { a, b in
            let scoreA = score(for: a)
            let scoreB = score(for: b)
            if scoreA != scoreB {
                return scoreA > scoreB
            }
            return a.createdAt < b.createdAt
        }

        let sortedDone = done.sorted { $0.createdAt < $1.createdAt }

        return sortedOpen + sortedDone
    }
}
