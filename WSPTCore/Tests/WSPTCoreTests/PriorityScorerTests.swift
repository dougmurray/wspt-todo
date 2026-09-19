import Foundation
import Testing
@testable import WSPTCore

@Suite("PriorityScorer")
struct PriorityScorerTests {

    // MARK: - score(importance:estimatedMinutes:)

    @Test("score formula matches importance / (2 × time)")
    func scoreFormula() {
        #expect(PriorityScorer.score(importance: .critical, estimatedMinutes: 30) == 5.0 / 60.0)
        #expect(PriorityScorer.score(importance: .normal, estimatedMinutes: 60) == 0.025)
        #expect(PriorityScorer.score(importance: .trivial, estimatedMinutes: 120) == 1.0 / 240)
    }

    @Test("zero or negative time scores as infinity")
    func zeroTimeGuard() {
        #expect(PriorityScorer.score(importance: .high, estimatedMinutes: 0) == .infinity)
        #expect(PriorityScorer.score(importance: .high, estimatedMinutes: -1) == .infinity)
    }

    @Test("importance raw values map 1-5 to the correct labels")
    func importanceLabels() {
        #expect(Importance.trivial.rawValue == 1 && Importance.trivial.label == "Trivial")
        #expect(Importance.low.rawValue == 2 && Importance.low.label == "Low")
        #expect(Importance.normal.rawValue == 3 && Importance.normal.label == "Normal")
        #expect(Importance.high.rawValue == 4 && Importance.high.label == "High")
        #expect(Importance.critical.rawValue == 5 && Importance.critical.label == "Critical")
    }

    // MARK: - rank(_:)

    @Test("open items are sorted descending by score")
    func ranksDescendingByScore() {
        let low = TodoItem(title: "low score", estimatedMinutes: 240, importance: .trivial)
        let high = TodoItem(title: "high score", estimatedMinutes: 30, importance: .critical)
        let mid = TodoItem(title: "mid score", estimatedMinutes: 60, importance: .normal)

        let ranked = PriorityScorer.rank([low, high, mid])

        #expect(ranked.map(\.title) == ["high score", "mid score", "low score"])
    }

    @Test("equal scores tie-break by createdAt ascending (oldest first)")
    func tieBreaksByCreatedAtOldestFirst() {
        let now = Date()
        let older = TodoItem(
            title: "older",
            estimatedMinutes: 60,
            importance: .normal,
            createdAt: now.addingTimeInterval(-100)
        )
        let newer = TodoItem(
            title: "newer",
            estimatedMinutes: 60,
            importance: .normal,
            createdAt: now
        )

        // Same score (both normal/60min), inserted with newer first to prove
        // tie-break reorders rather than preserving input order.
        let ranked = PriorityScorer.rank([newer, older])

        #expect(ranked.map(\.title) == ["older", "newer"])
    }

    @Test("done items always sink below open items, sorted by createdAt")
    func doneItemsSinkBelowOpenSortedByCreatedAt() {
        let now = Date()
        let openLowScore = TodoItem(title: "open low", estimatedMinutes: 600, importance: .trivial)
        let doneNewer = TodoItem(
            title: "done newer",
            estimatedMinutes: 15,
            importance: .critical,
            isDone: true,
            createdAt: now
        )
        let doneOlder = TodoItem(
            title: "done older",
            estimatedMinutes: 15,
            importance: .critical,
            isDone: true,
            createdAt: now.addingTimeInterval(-100)
        )

        let ranked = PriorityScorer.rank([doneNewer, doneOlder, openLowScore])

        // Even though the done items would score higher, they sink below
        // every open item, and among themselves sort oldest-created first.
        #expect(ranked.map(\.title) == ["open low", "done older", "done newer"])
    }

    @Test("rank is idempotent across repeated calls")
    func rankIsIdempotent() {
        let items = [
            TodoItem(title: "a", estimatedMinutes: 60, importance: .high),
            TodoItem(title: "b", estimatedMinutes: 120, importance: .low),
            TodoItem(title: "c", estimatedMinutes: 30, importance: .critical, isDone: true)
        ]

        let first = PriorityScorer.rank(items)
        let second = PriorityScorer.rank(first)

        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test("empty input ranks to empty output")
    func emptyInput() {
        #expect(PriorityScorer.rank([]).isEmpty)
    }

    // MARK: - Due-date urgency boost

    private func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: .now)!
    }

    @Test("item without a due date is unaffected")
    func noDueDateUnaffected() {
        let item = TodoItem(title: "plain", estimatedMinutes: 60, importance: .normal)
        let scores = PriorityScorer.effectiveScores(for: [item])
        #expect(scores[item.id] == PriorityScorer.score(for: item))
    }

    @Test("due date outside the urgency window is unaffected")
    func dueDateOutsideWindowUnaffected() {
        // Due item naturally at the bottom score — due 5 days out, beyond
        // the 3-day window, so it should score at its plain value.
        let high = TodoItem(title: "high", estimatedMinutes: 60, importance: .critical, createdAt: .now) // 5/120 = 0.0417
        let mid = TodoItem(title: "mid", estimatedMinutes: 100, importance: .critical, createdAt: .now) // 5/200 = 0.025
        let due = TodoItem(
            title: "due",
            estimatedMinutes: 250,
            importance: .critical,
            createdAt: .now,
            dueDate: daysFromNow(5)
        ) // 5/500 = 0.01

        let scores = PriorityScorer.effectiveScores(for: [high, mid, due])
        #expect(scores[due.id] == PriorityScorer.score(for: due))
        #expect(scores[high.id]! > scores[mid.id]! && scores[mid.id]! > scores[due.id]!)
    }

    @Test("climbing task lands at the midpoint of the item it passes and the one above it")
    func climbsToMidpointOfNextRank() {
        // Scores chosen for clean fractions: score = importance / (2 × minutes).
        // importance 5, minutes 5 -> 5/10 = 0.5
        let a = TodoItem(title: "a", estimatedMinutes: 5, importance: .critical) // 0.5
        // importance 3, minutes 5 -> 3/10 = 0.3
        let b = TodoItem(title: "b", estimatedMinutes: 5, importance: .normal) // 0.3
        // importance 2, minutes 5 -> 2/10 = 0.2, due in 2 days (1 climb step inside a 3-day window)
        let c = TodoItem(
            title: "c",
            estimatedMinutes: 5,
            importance: .low,
            dueDate: daysFromNow(2)
        ) // 0.2 base

        let scores = PriorityScorer.effectiveScores(for: [a, b, c])
        #expect(scores[a.id] == 0.5)
        #expect(scores[b.id] == 0.3)
        #expect(scores[c.id] == (0.3 + 0.5) / 2)
    }

    @Test("climbing task that reaches the top scores 20% above the previous top")
    func climbingPastTheTopBoostsAboveIt() {
        let a = TodoItem(title: "a", estimatedMinutes: 5, importance: .critical) // 0.5
        let b = TodoItem(title: "b", estimatedMinutes: 5, importance: .normal) // 0.3
        let c = TodoItem(
            title: "c",
            estimatedMinutes: 5,
            importance: .low,
            dueDate: daysFromNow(0)
        ) // 0.2 base, due today -> 3 climb steps -> reaches rank 0

        let scores = PriorityScorer.effectiveScores(for: [a, b, c])
        #expect(scores[c.id] == 0.5 * 1.2)

        let ranked = PriorityScorer.rank([a, b, c])
        #expect(ranked.map(\.title) == ["c", "a", "b"])
    }

    @Test("boost is frozen once the due date has passed, not escalating further")
    func boostFreezesAfterDueDate() {
        let a = TodoItem(title: "a", estimatedMinutes: 5, importance: .critical) // 0.5
        let b = TodoItem(title: "b", estimatedMinutes: 5, importance: .normal) // 0.3
        let dueToday = TodoItem(title: "due today", estimatedMinutes: 5, importance: .low, dueDate: daysFromNow(0))
        let overdue = TodoItem(title: "overdue", estimatedMinutes: 5, importance: .low, dueDate: daysFromNow(-10))

        let todayScore = PriorityScorer.effectiveScores(for: [a, b, dueToday])[dueToday.id]
        let overdueScore = PriorityScorer.effectiveScores(for: [a, b, overdue])[overdue.id]
        #expect(todayScore == overdueScore)
    }

    @Test("an already-top-ranked open item with a due date is unaffected")
    func alreadyTopRankedItemUnaffected() {
        let top = TodoItem(title: "top", estimatedMinutes: 5, importance: .critical, dueDate: daysFromNow(0))
        let lower = TodoItem(title: "lower", estimatedMinutes: 5, importance: .low)

        let scores = PriorityScorer.effectiveScores(for: [top, lower])
        #expect(scores[top.id] == PriorityScorer.score(for: top))
    }

    @Test("done items with a due date are never boosted")
    func doneItemsNeverBoosted() {
        let a = TodoItem(title: "a", estimatedMinutes: 5, importance: .critical) // 0.5
        let doneDue = TodoItem(
            title: "done due",
            estimatedMinutes: 5,
            importance: .low,
            isDone: true,
            dueDate: daysFromNow(0)
        )

        let scores = PriorityScorer.effectiveScores(for: [a, doneDue])
        #expect(scores[doneDue.id] == PriorityScorer.score(for: doneDue))
    }
}
