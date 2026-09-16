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
    var onEdit: () -> Void

    /// How far a rightward swipe has to travel to commit — there's no
    /// intermediate "Done" button to tap; crossing this distance marks the
    /// task done directly, mirroring swipe-to-complete apps like Reminders.
    private let completeThreshold: CGFloat = 70

    @State private var dragOffset: CGFloat = 0

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
        .offset(x: dragOffset)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .onTapGesture(count: 2, perform: onEdit)
        .gesture(
            DragGesture(minimumDistance: 16)
                .onChanged { value in
                    guard value.translation.width > 0 else { return }
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    if value.translation.width > completeThreshold {
                        withAnimation(.easeOut(duration: 0.18)) {
                            dragOffset = 600
                        }
                        Task {
                            try? await Task.sleep(nanoseconds: 160_000_000)
                            onToggleDone()
                        }
                    } else {
                        withAnimation(.interactiveSpring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
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
    var onEdit: () -> Void

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
            .onTapGesture(count: 2, perform: onEdit)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
                Button(action: onToggleDone) {
                    Label("Reopen", systemImage: "arrow.uturn.backward")
                }
                .tint(IOSPriorityTheme.accent)
            }
    }
}
#endif
