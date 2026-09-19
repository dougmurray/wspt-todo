#if os(macOS)
import SwiftUI
import WSPTCore

/// The macOS "List" tab: a hero card for the top-ranked open task, a
/// ranked table for the rest, and a compact add-task bar — mirroring the
/// Claude Design mockup's "2a" layout. `items` is expected pre-ranked by
/// `PriorityScorer.rank(_:)` (open items by score desc, then done items),
/// same ordering `ContentView` already computes for the iOS list.
struct PriorityListView: View {
    let items: [TodoItemModel]
    /// Effective (possibly due-date-boosted) score per item id, computed
    /// once by `ContentView` for the whole list.
    let scores: [UUID: Double]
    var onToggleDone: (TodoItemModel) -> Void
    var onDelete: (TodoItemModel) -> Void
    var onSave: (TodoItemModel, _ title: String, _ minutes: Double, _ importance: Importance, _ dueDate: Date?) -> Void
    var onAdd: (_ title: String, _ minutes: Double, _ importance: Importance, _ dueDate: Date?) -> Void

    private var openItems: [TodoItemModel] { items.filter { !$0.isDone } }
    private var doneItems: [TodoItemModel] { items.filter(\.isDone) }
    private var hero: TodoItemModel? { openItems.first }
    private var restItems: [TodoItemModel] { Array(openItems.dropFirst()) + doneItems }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let hero {
                    HeroCard(
                        item: hero,
                        score: scores[hero.id] ?? PriorityScorer.score(for: hero.asTodoItem),
                        onToggleDone: { onToggleDone(hero) },
                        onDelete: { onDelete(hero) },
                        onSave: { title, minutes, importance, dueDate in
                            onSave(hero, title, minutes, importance, dueDate)
                        }
                    )
                }

                if !restItems.isEmpty {
                    TableCard(
                        items: restItems,
                        scores: scores,
                        startRank: hero == nil ? 1 : 2,
                        onToggleDone: onToggleDone,
                        onDelete: onDelete,
                        onSave: onSave
                    )
                }

                AddTaskBar(onAdd: onAdd)
            }
            .padding(.vertical, 2)
        }
        .scrollContentBackground(.hidden)
    }
}

/// The green-tinted "Do this next" block for the single top-ranked open
/// task. Edit/done/delete controls are hover-revealed since the mockup
/// draws this as plain data — no functionality is lost, it's just quiet
/// until you point at it.
private struct HeroCard: View {
    let item: TodoItemModel
    let score: Double
    var onToggleDone: () -> Void
    var onDelete: () -> Void
    var onSave: (_ title: String, _ minutes: Double, _ importance: Importance, _ dueDate: Date?) -> Void

    @State private var isHovering = false
    @State private var showEdit = false

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            Circle()
                .strokeBorder(MacPriorityTheme.accent.opacity(0.5), lineWidth: 1.5)
                .frame(width: 24, height: 24)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("Do this next")
                    .font(MacPriorityTheme.label())
                    .tracking(0.8)
                    .foregroundStyle(MacPriorityTheme.accent)
                Text(item.title)
                    .font(MacPriorityTheme.serif(23))
                    .foregroundStyle(MacPriorityTheme.ink)
                HStack(spacing: 14) {
                    Text("Importance \(item.importance.rawValue)")
                    Rectangle().frame(width: 1, height: 13).foregroundStyle(MacPriorityTheme.ink(0.16))
                    Text(MacPriorityTheme.estimateLabel(minutes: item.estimatedMinutes))
                    if let dueDate = item.dueDate {
                        Rectangle().frame(width: 1, height: 13).foregroundStyle(MacPriorityTheme.ink(0.16))
                        Text(MacPriorityTheme.dueDateLabel(dueDate))
                    }
                }
                .font(MacPriorityTheme.sans(13))
                .foregroundStyle(MacPriorityTheme.ink(0.6))
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 7) {
                Text(MacPriorityTheme.formattedScore(score))
                    .font(MacPriorityTheme.serif(34))
                    .foregroundStyle(MacPriorityTheme.accent)
                Text("Score")
                    .font(MacPriorityTheme.label())
                    .tracking(0.8)
                    .foregroundStyle(MacPriorityTheme.accent.opacity(0.65))

                HStack(spacing: 10) {
                    Button(action: { showEdit = true }) {
                        Image(systemName: "pencil")
                    }
                    Button(action: onToggleDone) {
                        Image(systemName: item.isDone ? "arrow.uturn.backward" : "checkmark")
                    }
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MacPriorityTheme.accent.opacity(0.7))
                .opacity(isHovering ? 1 : 0)
                .padding(.top, 4)
            }
        }
        .padding(24)
        .background(MacPriorityTheme.accentTint)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(MacPriorityTheme.accentBorder))
        .onHover { isHovering = $0 }
        .popover(isPresented: $showEdit) {
            EditTaskPopover(
                initialTitle: item.title,
                initialMinutes: item.estimatedMinutes,
                initialImportance: item.importance,
                initialDueDate: item.dueDate,
                onSave: onSave
            )
        }
    }
}

/// The ranked table for every task after the hero, styled after the
/// mockup's `# / Task / Importance / Time / Score` grid. `Task` is the only
/// flexible column (`layoutPriority(-1)`, so it's always the first to
/// shrink/truncate) and every other column has `layoutPriority(1)`, so
/// Importance/Time/Score can never be squeezed out or pushed past the
/// card's trailing edge by a long title — HStack always sizes negative-
/// then-zero-priority children last, taking whatever the higher-priority
/// siblings don't need.
private struct TableCard: View {
    let items: [TodoItemModel]
    let scores: [UUID: Double]
    let startRank: Int
    var onToggleDone: (TodoItemModel) -> Void
    var onDelete: (TodoItemModel) -> Void
    var onSave: (TodoItemModel, _ title: String, _ minutes: Double, _ importance: Importance, _ dueDate: Date?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            TableHeaderRow()
            ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                if offset > 0 {
                    Divider().opacity(0.5)
                }
                TableRow(
                    item: item,
                    score: scores[item.id] ?? PriorityScorer.score(for: item.asTodoItem),
                    rank: startRank + offset,
                    onToggleDone: { onToggleDone(item) },
                    onDelete: { onDelete(item) },
                    onSave: { title, minutes, importance, dueDate in
                        onSave(item, title, minutes, importance, dueDate)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(MacPriorityTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(MacPriorityTheme.ink(0.09)))
    }
}

private struct TableHeaderRow: View {
    var body: some View {
        HStack(spacing: 16) {
            Text("#").frame(width: 20, alignment: .leading).layoutPriority(1)
            Text("Task").frame(maxWidth: .infinity, alignment: .leading).layoutPriority(-1)
            Text("Importance").frame(width: 74, alignment: .trailing).layoutPriority(1)
            Text("Time").frame(width: 60, alignment: .trailing).layoutPriority(1)
            Text("Score").frame(width: 50, alignment: .trailing).layoutPriority(1)
            Color.clear.frame(width: 62)
        }
        .font(MacPriorityTheme.label(10, weight: .medium))
        .tracking(0.6)
        .foregroundStyle(MacPriorityTheme.ink(0.42))
        .padding(.horizontal, 22)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(MacPriorityTheme.subtleCard)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(MacPriorityTheme.ink(0.08)), alignment: .bottom)
    }
}

private struct TableRow: View {
    let item: TodoItemModel
    let score: Double
    let rank: Int
    var onToggleDone: () -> Void
    var onDelete: () -> Void
    var onSave: (_ title: String, _ minutes: Double, _ importance: Importance, _ dueDate: Date?) -> Void

    @State private var isHovering = false
    @State private var showEdit = false

    var body: some View {
        HStack(spacing: 16) {
            Text("\(rank)")
                .foregroundStyle(MacPriorityTheme.ink(0.35))
                .frame(width: 20, alignment: .leading)
                .layoutPriority(1)

            Text(item.title)
                .font(MacPriorityTheme.serif(15.5))
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? MacPriorityTheme.ink(0.4) : MacPriorityTheme.ink(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(-1)

            Text("\(item.importance.rawValue)")
                .foregroundStyle(MacPriorityTheme.ink(item.isDone ? 0.4 : 0.6))
                .frame(width: 74, alignment: .trailing)
                .layoutPriority(1)

            Text(MacPriorityTheme.estimateLabel(minutes: item.estimatedMinutes))
                .foregroundStyle(MacPriorityTheme.ink(item.isDone ? 0.4 : 0.6))
                .frame(width: 60, alignment: .trailing)
                .layoutPriority(1)

            Text(MacPriorityTheme.formattedScore(score))
                .font(MacPriorityTheme.sans(14, weight: .medium))
                .foregroundStyle(MacPriorityTheme.ink(item.isDone ? 0.4 : 0.72))
                .frame(width: 50, alignment: .trailing)
                .layoutPriority(1)

            HStack(spacing: 8) {
                Button(action: { showEdit = true }) {
                    Image(systemName: "pencil")
                }
                Button(action: onToggleDone) {
                    Image(systemName: item.isDone ? "arrow.uturn.backward" : "checkmark")
                }
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(MacPriorityTheme.ink(0.45))
            .opacity(isHovering ? 1 : 0)
            .frame(width: 62, alignment: .trailing)
            .layoutPriority(1)
        }
        .font(MacPriorityTheme.sans(13))
        .padding(.horizontal, 22)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .popover(isPresented: $showEdit) {
            EditTaskPopover(
                initialTitle: item.title,
                initialMinutes: item.estimatedMinutes,
                initialImportance: item.importance,
                initialDueDate: item.dueDate,
                onSave: onSave
            )
        }
    }
}

/// Compact pill-style add bar: name field, importance menu, minutes field,
/// Add button — mirrors the mockup's bottom row.
private struct AddTaskBar: View {
    var onAdd: (_ title: String, _ minutes: Double, _ importance: Importance, _ dueDate: Date?) -> Void

    @State private var title = ""
    @State private var minutesText = ""
    @State private var importance: Importance = .normal
    @State private var dueDate: Date?
    @State private var showDuePicker = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                TextField("Add a task…", text: $title)
                    .textFieldStyle(.plain)
                    .foregroundStyle(MacPriorityTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .pillBackground()
                    .onSubmit(submit)

                Menu {
                    ForEach(Importance.allCases, id: \.self) { level in
                        Button("\(level.rawValue) — \(level.label)") { importance = level }
                    }
                } label: {
                    Text("Importance \(importance.rawValue)")
                        .font(MacPriorityTheme.sans(12.5, weight: .medium))
                        .foregroundStyle(MacPriorityTheme.ink(0.6))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .pillBackground()

                TextField("Min", text: $minutesText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(MacPriorityTheme.ink)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 40)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .pillBackground()
                    .onSubmit(submit)

                Button(action: { showDuePicker = true }) {
                    Image(systemName: dueDate == nil ? "calendar" : "calendar.badge.clock")
                }
                .buttonStyle(.plain)
                .foregroundStyle(dueDate == nil ? MacPriorityTheme.ink(0.5) : MacPriorityTheme.accent)
                .padding(10)
                .pillBackground()
                .popover(isPresented: $showDuePicker) {
                    // macOS's `.graphical` DatePicker ignores an outer
                    // `.frame()` and keeps its small fixed intrinsic size
                    // (~150×148pt), so enlarging it means scaling the
                    // rendered content itself and re-framing to that scaled
                    // size — a plain `.frame()` alone just pads blank space
                    // around an unchanged small calendar.
                    VStack(alignment: .leading, spacing: 14) {
                        DatePicker(
                            "Due date",
                            selection: Binding(get: { dueDate ?? .now }, set: { dueDate = $0 }),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .fixedSize()
                        .scaleEffect(1.8)
                        .frame(width: 150 * 1.8, height: 148 * 1.8)
                        if dueDate != nil {
                            Button("Clear due date", role: .destructive) { dueDate = nil }
                        }
                    }
                    .padding(18)
                }

                Button(action: submit) {
                    Text("Add")
                        .font(MacPriorityTheme.sans(12.5, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(MacPriorityTheme.accent)
                .clipShape(Capsule())
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(MacPriorityTheme.sans(11))
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(MacPriorityTheme.subtleCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(MacPriorityTheme.ink(0.09)))
    }

    private func submit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Enter a task name first."
            return
        }
        guard let minutes = Double(minutesText), minutes > 0 else {
            errorMessage = "Enter an estimated time greater than zero."
            return
        }

        errorMessage = nil
        onAdd(trimmedTitle, minutes, importance, dueDate)

        title = ""
        minutesText = ""
        importance = .normal
        dueDate = nil
    }
}

private extension View {
    /// The mockup's pale, thin-bordered pill background, shared by every
    /// control in the add bar.
    func pillBackground() -> some View {
        self
            .background(MacPriorityTheme.card)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(MacPriorityTheme.ink(0.12)))
    }
}
#endif
