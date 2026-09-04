import Foundation
import Testing
@testable import WSPTCore

@Suite("PriorityScorer")
struct PriorityScorerTests {

    // MARK: - score(importance:estimatedHours:)

    @Test("score formula matches importance / (2 × time)")
    func scoreFormula() {
        // 30 min "take recycling out" example from python-logic/tester.ipynb,
        // adapted to hours and the new 1-5/2x formula.
        #expect(PriorityScorer.score(importance: .critical, estimatedHours: 0.5) == 5.0)
        #expect(PriorityScorer.score(importance: .normal, estimatedHours: 1.0) == 1.5)
        #expect(PriorityScorer.score(importance: .trivial, estimatedHours: 2.0) == 0.25)
    }

    @Test("zero or negative time scores as infinity")
    func zeroTimeGuard() {
        #expect(PriorityScorer.score(importance: .high, estimatedHours: 0) == .infinity)
        #expect(PriorityScorer.score(importance: .high, estimatedHours: -1) == .infinity)
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
        let low = TodoItem(title: "low score", estimatedHours: 4, importance: .trivial)
        let high = TodoItem(title: "high score", estimatedHours: 0.5, importance: .critical)
        let mid = TodoItem(title: "mid score", estimatedHours: 1, importance: .normal)

        let ranked = PriorityScorer.rank([low, high, mid])

        #expect(ranked.map(\.title) == ["high score", "mid score", "low score"])
    }

    @Test("equal scores tie-break by createdAt ascending (oldest first)")
    func tieBreaksByCreatedAtOldestFirst() {
        let now = Date()
        let older = TodoItem(
            title: "older",
            estimatedHours: 1,
            importance: .normal,
            createdAt: now.addingTimeInterval(-100)
        )
        let newer = TodoItem(
            title: "newer",
            estimatedHours: 1,
            importance: .normal,
            createdAt: now
        )

        // Same score (both normal/1hr), inserted with newer first to prove
        // tie-break reorders rather than preserving input order.
        let ranked = PriorityScorer.rank([newer, older])

        #expect(ranked.map(\.title) == ["older", "newer"])
    }

    @Test("done items always sink below open items, sorted by createdAt")
    func doneItemsSinkBelowOpenSortedByCreatedAt() {
        let now = Date()
        let openLowScore = TodoItem(title: "open low", estimatedHours: 10, importance: .trivial)
        let doneNewer = TodoItem(
            title: "done newer",
            estimatedHours: 0.25,
            importance: .critical,
            isDone: true,
            createdAt: now
        )
        let doneOlder = TodoItem(
            title: "done older",
            estimatedHours: 0.25,
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
            TodoItem(title: "a", estimatedHours: 1, importance: .high),
            TodoItem(title: "b", estimatedHours: 2, importance: .low),
            TodoItem(title: "c", estimatedHours: 0.5, importance: .critical, isDone: true)
        ]

        let first = PriorityScorer.rank(items)
        let second = PriorityScorer.rank(first)

        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test("empty input ranks to empty output")
    func emptyInput() {
        #expect(PriorityScorer.rank([]).isEmpty)
    }
}
