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

/// Root view. On iOS this follows the Claude Design mockup ("WSPT To Do App
/// UI" project, turn 6 — "iOS, stacked color bars"): a green "To Do" header
/// and a continuous stack of full-bleed colored rows for open tasks falling
/// in intensity with rank, with a "Done" section below. A pull-down gesture
/// (rather than the mockup's implied "+" affordance, which had no visible
/// control to mirror) presents `AddTodoForm` full-screen. On macOS it
/// instead follows that project's turn 3 ("Today" header, List/Plot tabs)
/// — see CLAUDE.md's platform-branch convention.
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

    /// Effective (possibly due-date-boosted) score per item, computed once
    /// per view evaluation alongside `rankedItems` so rows display the same
    /// number that determined their rank rather than recomputing the plain
    /// WSPT score in isolation.
    private var scores: [UUID: Double] {
        PriorityScorer.effectiveScores(for: items.map(\.asTodoItem))
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
                    scores: scores,
                    onToggleDone: toggleDone,
                    onDelete: delete,
                    onSave: updateItem,
                    onAdd: addItem
                )
            } else {
                PriorityPlotView(
                    items: rankedItems,
                    scores: scores,
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

    #endif

    // MARK: - iOS

    #if os(iOS)
    @State private var isAddingTask = false
    /// Non-nil while `AddTodoForm` is presented in edit mode for this task
    /// — set by a double tap on its row (see `queueList`).
    @State private var editingItem: TodoItemModel?

    private var openRanked: [TodoItemModel] { rankedItems.filter { !$0.isDone } }
    private var doneRanked: [TodoItemModel] { rankedItems.filter(\.isDone) }

    /// `.refreshable`'s pull indicator needs a moment to animate back to
    /// rest before its content is covered — flipping `isAddingTask`
    /// synchronously (the action closure returning immediately) can leave
    /// the list stuck with a blank gap under the header after the cover is
    /// dismissed, because the collapse animation gets cut off by the cover
    /// appearing mid-animation. Staying "in progress" for a beat first lets
    /// the indicator finish collapsing before `AddTodoForm` is presented.
    private func beginAddingTask() async {
        try? await Task.sleep(nanoseconds: 200_000_000)
        isAddingTask = true
    }

    private var iosBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if items.isEmpty {
                    ScrollView {
                        EmptyStateView()
                            .padding(.horizontal)
                    }
                    .refreshable { await beginAddingTask() }
                    .tint(.white)
                    .scrollContentBackground(.hidden)
                } else {
                    queueList
                }
            }
            .background(IOSPriorityTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $isAddingTask) {
            AddTodoForm(onAdd: addItem)
        }
        .fullScreenCover(item: $editingItem) { item in
            AddTodoForm(
                editingItem: item.asTodoItem,
                onSave: { title, minutes, importance, dueDate in
                    updateItem(item, title: title, minutes: minutes, importance: importance, dueDate: dueDate)
                }
            )
        }
    }

    private var header: some View {
        Text("To Do")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 20)
            .background(IOSPriorityTheme.accent.ignoresSafeArea(edges: .top))
    }

    /// Pulling down on the queue (`.refreshable`, rather than a "+" button
    /// the mockup didn't show) presents `AddTodoForm`.
    private var queueList: some View {
        List {
            ForEach(Array(openRanked.enumerated()), id: \.element.id) { index, item in
                TodoRow(
                    item: item,
                    score: scores[item.id] ?? PriorityScorer.score(for: item.asTodoItem),
                    rankIndex: index,
                    totalOpen: openRanked.count,
                    onToggleDone: { toggleDone(item) },
                    onDelete: { delete(item) },
                    onEdit: { editingItem = item }
                )
            }

            if !doneRanked.isEmpty {
                doneSectionHeader
                ForEach(Array(doneRanked.enumerated()), id: \.element.id) { index, item in
                    DoneTodoRow(
                        item: item,
                        fadeIndex: index,
                        onToggleDone: { toggleDone(item) },
                        onDelete: { delete(item) },
                        onEdit: { editingItem = item }
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(IOSPriorityTheme.background)
        .refreshable { await beginAddingTask() }
        .tint(.white)
    }

    private var doneSectionHeader: some View {
        Text("Done")
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    #endif

    // MARK: - Mutations

    private func addItem(title: String, minutes: Double, importance: Importance, dueDate: Date?) {
        let newItem = TodoItemModel(
            title: title,
            estimatedMinutes: minutes,
            importance: importance,
            dueDate: dueDate
        )
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

    private func updateItem(
        _ item: TodoItemModel,
        title: String,
        minutes: Double,
        importance: Importance,
        dueDate: Date?
    ) {
        item.title = title
        item.estimatedMinutes = minutes
        item.importance = importance
        item.dueDate = dueDate
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TodoItemModel.self, inMemory: true)
}
