import SwiftUI
import WSPTCore

/// A single ranked row: score badge, title, meta line, done/delete actions.
/// Mirrors `.item` / `.score-col` / `.item-body` / `.item-actions` in
/// docs/wspt-todo.html (lines 157-249).
struct TodoRow: View {
    let item: TodoItemModel
    var onToggleDone: () -> Void
    var onDelete: () -> Void

    private var score: Double {
        PriorityScorer.score(for: item.asTodoItem)
    }

    private var formattedScore: String {
        score.isInfinite ? "∞" : String(format: "%.2f", score)
    }

    private var minutesLabel: String {
        let mins = item.estimatedMinutes
        let formatted = mins.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", mins)
            : String(format: "%.2f", mins)
        return "\(formatted) min\(mins == 1 ? "" : "s")"
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(formattedScore)
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.teal)
                Text("score")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.25))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)

                HStack(spacing: 10) {
                    Label(minutesLabel, systemImage: "clock")
                    Label(item.importance.label, systemImage: "flag")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                Button(action: onToggleDone) {
                    Image(systemName: item.isDone ? "arrow.uturn.backward" : "checkmark")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .accessibilityLabel(item.isDone ? "Mark as not done" : "Mark as done")

                Divider()

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .accessibilityLabel("Delete task")
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(width: 40)
        }
        .opacity(item.isDone ? 0.45 : 1)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        #if os(iOS)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onToggleDone) {
                Label(
                    item.isDone ? "Reopen" : "Done",
                    systemImage: item.isDone ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(.teal)
        }
        #endif
    }
}
