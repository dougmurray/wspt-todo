import Foundation
import SwiftData
import WSPTCore

/// The persisted SwiftData model for a todo item.
///
/// Deliberately a separate type from `WSPTCore.TodoItem` (the pure domain
/// struct used for scoring/ranking) rather than making `TodoItem` itself a
/// `@Model` — this keeps persistence-layer concerns (SwiftData, and later
/// CloudKit) isolated from the tested scoring logic.
///
/// Every property has a literal default and there are no unique
/// constraints, per CloudKit's SwiftData requirements — so this model can
/// gain a CloudKit-backed `ModelConfiguration` later without a schema
/// rework.
@Model
final class TodoItemModel {
    var id: UUID = UUID()
    var title: String = ""
    /// Estimated time to complete the task, in hours.
    var estimatedHours: Double = 1.0
    /// Backing storage for `importance`; kept as a plain Int for
    /// CloudKit-friendliness.
    var importanceRaw: Int = Importance.normal.rawValue
    var isDone: Bool = false
    var createdAt: Date = Date.now

    init(
        title: String,
        estimatedHours: Double,
        importance: Importance,
        isDone: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.estimatedHours = estimatedHours
        self.importanceRaw = importance.rawValue
        self.isDone = isDone
        self.createdAt = createdAt
    }

    var importance: Importance {
        get { Importance(rawValue: importanceRaw) ?? .normal }
        set { importanceRaw = newValue.rawValue }
    }

    /// Maps this persisted model to the pure `TodoItem` value type that
    /// `PriorityScorer` operates on.
    var asTodoItem: TodoItem {
        TodoItem(
            id: id,
            title: title,
            estimatedHours: estimatedHours,
            importance: importance,
            isDone: isDone,
            createdAt: createdAt
        )
    }
}
