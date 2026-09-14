#if os(iOS)
import SwiftUI
import WSPTCore

/// A single open, ranked task rendered as a full-bleed colored band — mirrors
/// option 6a's stacked queue in the Claude Design mockup ("WSPT To Do App
/// UI" project, turn 6): no card, no divider, just a band whose background
/// intensity falls with rank (`IOSPriorityTheme.rowColor`) and title/meta/
/// score all in white. Swipe actions (not shown in the mockup, which is a
/// static screenshot) preserve done/delete without adding any visible chrome.
struct TodoRow: View {
    let item: TodoItemModel
    /// This task's position among open tasks (0 = top of the queue) — feeds
    /// `IOSPriorityTheme.rowColor` so intensity falls smoothly with rank.
    let rankIndex: Int
    let totalOpen: Int
    var onToggleDone: () -> Void
    var onDelete: () -> Void

    private var score: Double {
        PriorityScorer.score(for: item.asTodoItem)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(item.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(IOSPriorityTheme.minutesLabel(item.estimatedMinutes)) · Importance \(item.importance.rawValue)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 12)
            Text(IOSPriorityTheme.formattedScore(score))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IOSPriorityTheme.rowColor(atIndex: rankIndex, of: totalOpen))
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .leading) {
            Button(action: onToggleDone) {
                Label("Done", systemImage: "checkmark")
            }
            .tint(IOSPriorityTheme.accent)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// A completed task in the "Done" section below the queue — plain
/// strikethrough text fading with recency, mirroring option 6a's bottom
/// block: no band color and no score shown there, just the title.
struct DoneTodoRow: View {
    let item: TodoItemModel
    /// Position within the done section (0 = most recently completed) —
    /// feeds `IOSPriorityTheme.doneOpacity` so older items fade further.
    let fadeIndex: Int
    var onToggleDone: () -> Void
    var onDelete: () -> Void

    private var opacity: Double {
        IOSPriorityTheme.doneOpacity(atIndex: fadeIndex)
    }

    var body: some View {
        Text(item.title)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(.white.opacity(opacity))
            .strikethrough(true, color: .white.opacity(opacity))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                Button(action: onToggleDone) {
                    Label("Reopen", systemImage: "arrow.uturn.backward")
                }
                .tint(IOSPriorityTheme.accent)
            }
    }
}
#endif
