import Foundation

/// A pure, persistence-agnostic todo item.
///
/// This is the type WSPT scoring/ranking logic operates on. The app target's
/// SwiftData `@Model` is a separate type that maps to/from this one, so
/// persistence-layer changes (adding CloudKit, adding fields) never touch
/// the tested scoring logic in `PriorityScorer`.
public struct TodoItem: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var title: String
    /// Estimated time to complete the task, in minutes.
    public var estimatedMinutes: Double
    public var importance: Importance
    public var isDone: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        estimatedMinutes: Double,
        importance: Importance,
        isDone: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.importance = importance
        self.isDone = isDone
        self.createdAt = createdAt
    }
}
