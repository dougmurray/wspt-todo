#if os(macOS)
import SwiftUI
import WSPTCore

/// The macOS "Plot" tab: a scatter chart of importance vs. estimated time,
/// with a detail panel for whichever task is selected — mirrors the Claude
/// Design mockup's "3a" plot option. `items` is expected pre-ranked by
/// `PriorityScorer.rank(_:)`, same as `PriorityListView`.
struct PriorityPlotView: View {
    let items: [TodoItemModel]
    /// Effective (possibly due-date-boosted) score per item id, computed
    /// once by `ContentView` for the whole list.
    let scores: [UUID: Double]
    @Binding var selectedID: UUID?
    var onToggleDone: (TodoItemModel) -> Void
    var onDelete: (TodoItemModel) -> Void
    var onSave: (TodoItemModel, _ title: String, _ minutes: Double, _ importance: Importance, _ dueDate: Date?) -> Void

    private var selected: TodoItemModel? {
        if let selectedID, let match = items.first(where: { $0.id == selectedID }) {
            return match
        }
        return items.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                chartCard

                if let selected {
                    DetailPanel(
                        item: selected,
                        score: scores[selected.id] ?? PriorityScorer.score(for: selected.asTodoItem),
                        rank: rank(of: selected),
                        total: items.count,
                        onToggleDone: { onToggleDone(selected) },
                        onDelete: { onDelete(selected) },
                        onSave: { title, minutes, importance, dueDate in
                            onSave(selected, title, minutes, importance, dueDate)
                        }
                    )
                } else {
                    Text("No tasks to inspect yet.")
                        .font(MacPriorityTheme.sans(13))
                        .foregroundStyle(MacPriorityTheme.ink(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(30)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            if selectedID == nil { selectedID = items.first?.id }
        }
    }

    private func rank(of item: TodoItemModel) -> Int {
        (items.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Priority field")
                    .font(MacPriorityTheme.serif(17))
                Spacer()
                Text("Tap a dot to inspect it")
                    .font(MacPriorityTheme.sans(12))
                    .foregroundStyle(MacPriorityTheme.ink(0.5))
            }

            ScatterChart(items: items, selectedID: selectedID, onSelect: { selectedID = $0 })
                .frame(height: 260)

            HStack {
                Text("15m")
                Spacer()
                Text("1h")
                Spacer()
                Text("2h")
                Spacer()
                Text("3h")
                Spacer()
                Text("4h")
            }
            .font(MacPriorityTheme.sans(11))
            .foregroundStyle(MacPriorityTheme.ink(0.42))

            Text("Takes longer →")
                .font(MacPriorityTheme.label(10))
                .tracking(0.6)
                .foregroundStyle(MacPriorityTheme.ink(0.4))
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(MacPriorityTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(MacPriorityTheme.ink(0.09)))
    }
}

/// Plots each task as importance (y, 5 at top) against estimated time
/// (x, 15m–4h, clamped), tap a dot to select it. Same axis mapping as the
/// design canvas's `plotDots` generator.
private struct ScatterChart: View {
    let items: [TodoItemModel]
    let selectedID: UUID?
    var onSelect: (UUID) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                }
                .stroke(MacPriorityTheme.ink(0.16), lineWidth: 1)

                Text("Do first")
                    .font(MacPriorityTheme.label(10))
                    .tracking(0.6)
                    .foregroundStyle(MacPriorityTheme.accent.opacity(0.75))
                    .padding(10)

                Text("Do last")
                    .font(MacPriorityTheme.label(10))
                    .tracking(0.6)
                    .foregroundStyle(MacPriorityTheme.ink(0.3))
                    .padding(10)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomTrailing)

                // Non-selected dots first, selected dot last (topmost) —
                // real task durations cluster tightly (lots of ~10-30m
                // items), so two dots landing on nearly the same spot is
                // common; without a deliberate draw order the selected
                // dot could end up hidden under a same-position sibling.
                ForEach(nonSelectedItems) { item in
                    dot(for: item, index: rankIndex[item.id] ?? 0, isSelected: false, in: geo.size)
                }
                if let selected = items.first(where: { $0.id == selectedID }) {
                    dot(for: selected, index: rankIndex[selected.id] ?? 0, isSelected: true, in: geo.size)
                }
            }
        }
        .background(
            RadialGradient(
                colors: [MacPriorityTheme.accent.opacity(0.08), .clear],
                center: .topLeading, startRadius: 0, endRadius: 280
            )
        )
    }

    private var nonSelectedItems: [TodoItemModel] {
        items.filter { $0.id != selectedID }
    }

    /// Each item's position in the (already rank-ordered) `items` array,
    /// used to shade the top half of open tasks with the accent tint.
    /// `PriorityScorer`'s scores are minutes-based (typically 0.01–0.3),
    /// not the mockup's illustrative hours-based 0.25–8.00 range, so a
    /// fixed absolute cutoff like the mockup's `score >= 2.5` would never
    /// trigger on real data — every dot but the selected one would render
    /// in the same low-contrast muted color. Rank position works
    /// regardless of the formula's absolute scale.
    private var rankIndex: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) })
    }

    private var openCount: Int {
        items.filter { !$0.isDone }.count
    }

    private func dot(for item: TodoItemModel, index: Int, isSelected: Bool, in size: CGSize) -> some View {
        let hours = min(max(item.estimatedMinutes / 60, 0.25), 4)
        let x = (0.06 + (hours / 4) * 0.86) * size.width
        let y = ((Double(5 - item.importance.rawValue) / 4) * 0.82 + 0.08) * size.height
        let dotSize: CGFloat = isSelected ? 16 : 11
        // A small, stable per-item nudge so tasks with identical/near-
        // identical importance and time (common with short, similar
        // estimates) don't render as one indistinguishable dot.
        let jitter = isSelected ? (dx: CGFloat(0), dy: CGFloat(0)) : stableJitter(for: item.id)

        return Circle()
            .fill(dotColor(index: index, isDone: item.isDone, isSelected: isSelected))
            .frame(width: dotSize, height: dotSize)
            .overlay(Circle().stroke(MacPriorityTheme.card, lineWidth: 1.5))
            .overlay {
                if isSelected {
                    Circle()
                        .stroke(MacPriorityTheme.accent.opacity(0.2), lineWidth: 5)
                        .frame(width: dotSize + 10, height: dotSize + 10)
                }
            }
            .position(x: x + jitter.dx, y: y + jitter.dy)
            .onTapGesture { onSelect(item.id) }
    }

    private func stableJitter(for id: UUID) -> (dx: CGFloat, dy: CGFloat) {
        var hasher = Hasher()
        hasher.combine(id)
        let hash = hasher.finalize()
        let dx = CGFloat(hash % 7) - 3
        let dy = CGFloat((hash / 7) % 7) - 3
        return (dx, dy)
    }

    private func dotColor(index: Int, isDone: Bool, isSelected: Bool) -> Color {
        if isSelected { return MacPriorityTheme.accent }
        if isDone { return MacPriorityTheme.ink(0.16) }
        return index < max(1, openCount / 2) ? MacPriorityTheme.accent.opacity(0.55) : MacPriorityTheme.ink(0.4)
    }
}

/// Green-tinted panel describing whichever task is selected in the chart,
/// with Edit / Start now / delete controls.
private struct DetailPanel: View {
    let item: TodoItemModel
    let score: Double
    let rank: Int
    let total: Int
    var onToggleDone: () -> Void
    var onDelete: () -> Void
    var onSave: (_ title: String, _ minutes: Double, _ importance: Importance, _ dueDate: Date?) -> Void

    @State private var showEdit = false

    /// `PriorityScorer` divides by minutes, not hours — mirror that here
    /// so this caption's arithmetic actually matches the Score number
    /// above it (the mockup's illustrative "N ÷ (2 × 0.25h)" style assumed
    /// an hours-based formula this app doesn't use).
    private var minutesLabel: String {
        MacPriorityTheme.plainMinutes(item.estimatedMinutes) + "m"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 26) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Selected · rank \(rank) of \(total)")
                    .font(MacPriorityTheme.label())
                    .tracking(0.8)
                    .foregroundStyle(MacPriorityTheme.accent)
                Text(item.title)
                    .font(MacPriorityTheme.serif(22))
                    .strikethrough(item.isDone)
                    .foregroundStyle(MacPriorityTheme.ink)

                HStack(alignment: .top, spacing: 30) {
                    field("Importance", "\(item.importance.rawValue)")
                    field("Estimate", MacPriorityTheme.estimateLabel(minutes: item.estimatedMinutes))
                    field("Math", "\(item.importance.rawValue) ÷ (2 × \(minutesLabel))")
                    if let dueDate = item.dueDate {
                        field("Due", MacPriorityTheme.dueDateLabel(dueDate))
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 7) {
                Text(MacPriorityTheme.formattedScore(score))
                    .font(MacPriorityTheme.serif(40))
                    .foregroundStyle(MacPriorityTheme.accent)
                Text("Score")
                    .font(MacPriorityTheme.label())
                    .tracking(0.8)
                    .foregroundStyle(MacPriorityTheme.accent.opacity(0.65))

                HStack(spacing: 8) {
                    Button("Edit") { showEdit = true }
                        .buttonStyle(.bordered)
                    Button(item.isDone ? "Reopen" : "Start now", action: onToggleDone)
                        .buttonStyle(.borderedProminent)
                        .tint(MacPriorityTheme.accent)
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                }
                .font(MacPriorityTheme.sans(12.5, weight: .medium))
                .padding(.top, 8)
            }
        }
        .padding(22)
        .background(MacPriorityTheme.accentTint)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(MacPriorityTheme.accentBorder))
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

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(MacPriorityTheme.label(10))
                .tracking(0.6)
                .foregroundStyle(MacPriorityTheme.ink(0.45))
            Text(value)
                .font(MacPriorityTheme.sans(15))
                .foregroundStyle(MacPriorityTheme.ink)
        }
    }
}
#endif
