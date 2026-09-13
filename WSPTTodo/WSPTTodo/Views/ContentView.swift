import SwiftUI
import SwiftData
import WSPTCore

#if os(macOS)
/// Which of the two macOS tabs — ranked list or scatter plot — is showing.
enum PriorityViewMode {
    case list
    case plot
}
#endif

/// Root view. On iOS this mirrors the overall page structure of
/// docs/wspt-todo.html: header + formula badge, add form, open-count
/// header, ranked list / empty state. On macOS it instead follows the
/// Claude Design mockup ("WSPT To Do App UI" project): a "Today" header,
/// a List/Plot tab switcher, and either `PriorityListView` or
/// `PriorityPlotView` for the body — see CLAUDE.md's platform-branch
/// convention.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItemModel.createdAt) private var items: [TodoItemModel]

    #if os(macOS)
    @State private var viewMode: PriorityViewMode = .list
    @State private var selectedID: UUID?
    #endif

    /// Ranks the fetched models via `PriorityScorer.rank(_:)` — the score is
    /// computed, not stored, and the full list is re-ranked on every view
    /// evaluation (i.e. after every mutation), per the "recompute on every
    /// mutation" rule in docs/overvall-plan.md. `@Query`'s own sort
    /// parameter can't express the WSPT formula, the infinity guard, or the
    /// open/done split, so ranking happens here instead.
    private var rankedItems: [TodoItemModel] {
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return PriorityScorer.rank(items.map(\.asTodoItem)).compactMap { byID[$0.id] }
    }

    private var openCount: Int {
        items.filter { !$0.isDone }.count
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iosBody
        #endif
    }

    // MARK: - macOS

    #if os(macOS)
    private var openTotalMinutes: Double {
        items.filter { !$0.isDone }.reduce(0) { $0 + $1.estimatedMinutes }
    }

    private var macBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            macHeader
            if items.isEmpty {
                EmptyStateView()
                    .frame(maxWidth: .infinity)
            } else if viewMode == .list {
                PriorityListView(
                    items: rankedItems,
                    onToggleDone: toggleDone,
                    onDelete: delete,
                    onSave: updateItem,
                    onAdd: addItem
                )
            } else {
                PriorityPlotView(
                    items: rankedItems,
                    selectedID: $selectedID,
                    onToggleDone: toggleDone,
                    onDelete: delete,
                    onSave: updateItem
                )
            }
        }
        .padding(28)
        .frame(minWidth: 760, minHeight: 600)
        .background(MacPriorityTheme.background)
        // The mockup's palette is fixed-light (warm cream cards, dark ink
        // text) rather than adapting to the system appearance. Without
        // this, a system in Dark Mode renders text fields' default label
        // color as white-on-cream — invisible.
        .preferredColorScheme(.light)
    }

    private var macHeader: some View {
        HStack(alignment: .lastTextBaseline, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today")
                    .font(MacPriorityTheme.serif(27))
                    .foregroundStyle(MacPriorityTheme.ink)
                Text(macSubtitle)
                    .font(MacPriorityTheme.sans(13))
                    .foregroundStyle(MacPriorityTheme.ink(0.52))
            }
            Spacer()
            if !items.isEmpty {
                viewModeSwitcher
            }
        }
    }

    private var macSubtitle: String {
        let taskWord = openCount == 1 ? "One task" : "\(openCount) tasks"
        let duration = MacPriorityTheme.formattedDuration(minutes: openTotalMinutes)
        return "\(taskWord) · \(duration) estimated · priority = importance ÷ (2 × time)"
    }

    private var viewModeSwitcher: some View {
        HStack(spacing: 4) {
            switcherButton("List", mode: .list)
            switcherButton("Plot", mode: .plot)
        }
        .padding(4)
        .background(MacPriorityTheme.subtleCard)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(MacPriorityTheme.ink(0.1)))
    }

    private func switcherButton(_ title: String, mode: PriorityViewMode) -> some View {
        let isSelected = viewMode == mode
        return Button(action: { viewMode = mode }) {
            Text(title)
                .font(MacPriorityTheme.sans(12.5, weight: .medium))
                .foregroundStyle(isSelected ? MacPriorityTheme.ink : MacPriorityTheme.ink(0.55))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(isSelected ? MacPriorityTheme.card : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func updateItem(_ item: TodoItemModel, title: String, minutes: Double, importance: Importance) {
        item.title = title
        item.estimatedMinutes = minutes
        item.importance = importance
        try? modelContext.save()
    }
    #endif

    // MARK: - iOS

    #if os(iOS)
    private var iosBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding([.horizontal, .top])

                AddTodoForm(onAdd: addItem)
                    .padding(.horizontal)
                    .padding(.top, 12)

                openCountHeader
                    .padding(.horizontal)
                    .padding(.top, 16)

                if items.isEmpty {
                    EmptyStateView()
                        .padding(.horizontal)
                } else {
                    List {
                        ForEach(rankedItems) { item in
                            TodoRow(
                                item: item,
                                onToggleDone: { toggleDone(item) },
                                onDelete: { delete(item) }
                            )
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Priority queue")
                .font(.title2.weight(.semibold))
            Spacer()
            Text("P = I / (2×t)")
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.18))
                .foregroundStyle(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private var openCountHeader: some View {
        HStack {
            Text(openCount == 1 ? "1 open task" : "\(openCount) open tasks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    #endif

    // MARK: - Mutations

    private func addItem(title: String, minutes: Double, importance: Importance) {
        let newItem = TodoItemModel(title: title, estimatedMinutes: minutes, importance: importance)
        modelContext.insert(newItem)
        try? modelContext.save()
    }

    private func toggleDone(_ item: TodoItemModel) {
        item.isDone.toggle()
        try? modelContext.save()
    }

    private func delete(_ item: TodoItemModel) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TodoItemModel.self, inMemory: true)
}
