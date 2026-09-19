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

    // MARK: - Due-date urgency boost

    /// How many days before `dueDate` the urgency boost starts climbing.
    /// Outside this window a due item scores exactly like `score(for:)`.
    public static let dueDateUrgencyWindowDays = 3

    /// The effective (possibly due-date-boosted) score for every item,
    /// keyed by `id`. Open items without a `dueDate`, and all done items,
    /// map to their plain `score(for:)`. Open items with a `dueDate` climb
    /// one rank position per day once within `dueDateUrgencyWindowDays` of
    /// the deadline: each day, the item's score is pushed to just above the
    /// item currently one rank above it (base-score ranking), so it moves
    /// up the queue one position per day — reaching the top exactly on the
    /// due date if there are at least `dueDateUrgencyWindowDays` items above
    /// it — and stops rising once it has nothing left to climb above.
    /// Frozen (not further boosted) once the due date has passed.
    public static func effectiveScores(for items: [TodoItem], today: Date = .now) -> [UUID: Double] {
        let open = items.filter { !$0.isDone }
        let baseRanked = open.sorted { a, b in
            let scoreA = score(for: a)
            let scoreB = score(for: b)
            if scoreA != scoreB {
                return scoreA > scoreB
            }
            return a.createdAt < b.createdAt
        }

        var result: [UUID: Double] = [:]
        for (index, item) in baseRanked.enumerated() {
            result[item.id] = effectiveScore(for: item, naturalRank: index, in: baseRanked, today: today)
        }
        for item in items where item.isDone {
            result[item.id] = score(for: item)
        }
        return result
    }

    /// See `effectiveScores(for:today:)`. `baseRanked` is the full open-item
    /// ranking by plain score, and `naturalRank` is this item's index in it.
    private static func effectiveScore(
        for item: TodoItem,
        naturalRank: Int,
        in baseRanked: [TodoItem],
        today: Date
    ) -> Double {
        let base = score(for: item)
        guard let dueDate = item.dueDate else { return base }

        let calendar = Calendar.current
        let daysUntilDue = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: today),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? dueDateUrgencyWindowDays

        // Climbs by 1 for each day inside the window; clamping the upper
        // bound at the window size is what freezes the boost once the due
        // date has passed, rather than letting it keep escalating.
        let climbSteps = min(max(dueDateUrgencyWindowDays - daysUntilDue, 0), dueDateUrgencyWindowDays)
        guard climbSteps > 0 else { return base }

        let targetRank = max(0, naturalRank - climbSteps)
        guard targetRank != naturalRank else { return base }

        let target = baseRanked[targetRank]
        let targetScore = score(for: target)
        guard targetScore.isFinite else { return targetScore }

        guard targetRank > 0 else {
            // Nothing ranks above the target — it's already the top open
            // item, so there's no "next higher score" to land between.
            return targetScore * 1.2
        }

        let neighborAboveScore = score(for: baseRanked[targetRank - 1])
        guard neighborAboveScore.isFinite else { return targetScore }
        return (targetScore + neighborAboveScore) / 2
    }

    /// Ranks items for display: open items first (highest effective score
    /// first — see `effectiveScores(for:today:)` — ties broken by oldest
    /// `createdAt` first), followed by done items (oldest `createdAt`
    /// first). Always recomputes from scratch — call this after every
    /// insert/edit/toggle/delete rather than trying to update in place.
    public static func rank(_ items: [TodoItem], today: Date = .now) -> [TodoItem] {
        let open = items.filter { !$0.isDone }
        let done = items.filter { $0.isDone }
        let scores = effectiveScores(for: items, today: today)

        let sortedOpen = open.sorted { a, b in
            let scoreA = scores[a.id] ?? score(for: a)
            let scoreB = scores[b.id] ?? score(for: b)
            if scoreA != scoreB {
                return scoreA > scoreB
            }
            return a.createdAt < b.createdAt
        }

        let sortedDone = done.sorted { $0.createdAt < $1.createdAt }

        return sortedOpen + sortedDone
    }
}
