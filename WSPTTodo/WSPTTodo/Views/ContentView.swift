import SwiftUI
import SwiftData
import WSPTCore

/// Root view. Mirrors the overall page structure of docs/wspt-todo.html:
/// header + formula badge, add form, open-count header, ranked list /
/// empty state.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItemModel.createdAt) private var items: [TodoItemModel]

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
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
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

    private func addItem(title: String, hours: Double, importance: Importance) {
        let newItem = TodoItemModel(title: title, estimatedHours: hours, importance: importance)
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
