# Basic outline plan

## Architecture
Build this as a native SwiftUI app targeting both iOS and macOS from one codebase (a Swift Package with shared model/logic, plus thin platform-specific UI). Use SwiftData for persistence with CloudKit syncing so items stay current across iPhone and Mac. Xcode is really the only path here — this isn't something to reach for cross-platform frameworks for, given how well SwiftUI now covers both targets.

## On the algorithm
Your formula is right — priority = importance / (2.0 × estimated_time), then sort descending. A few refinements worth considering:

- **Recompute on every mutation.** Any insert, edit, or completion should trigger a full re-sort rather than trying to do an incremental update — with a normal-sized todo list this is computationally trivial.
- **Watch for starvation.** Classic WSPT has no notion of urgency/deadlines — a low-importance, long task can sit at the bottom forever. Consider an "aging" term that slowly boosts priority the longer an item sits untouched, or a separate due-date field that overrides WSPT ordering when a deadline is close (essentially blending WSPT with earliest-due-date logic).
- **Tie-breaking.** When two items compute to the same priority, break ties by creation timestamp (oldest first) so the order doesn't jitter.

## On the importance scale — I'd go with 1–5, not 1–10. A few reasons:

- Human ability to make consistent, meaningful distinctions on an unlabeled numeric scale tops out around 5–7 categories (Miller's "7±2"). A 1–10 scale invites false precision — people can't reliably tell "importance 6" from "importance 7," so the extra resolution is mostly noise.
- Label the points instead of leaving them as bare numbers: e.g. 1 = Trivial, 2 = Low, 3 = Normal, 4 = High, 5 = Critical. Labels anchor judgment far better than raw numbers do.
- If you want more spread in the resulting priority values without adding decision fatigue, use a non-linear scale (1, 2, 3, 5, 8 — Fibonacci-style, same idea agile teams use for story points) instead of jumping to 1–10. It keeps the same 5 choices but spaces the consequences of each choice further apart.
