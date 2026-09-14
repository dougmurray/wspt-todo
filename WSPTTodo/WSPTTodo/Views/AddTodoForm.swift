#if os(iOS)
import SwiftUI
import WSPTCore

/// The "New task" screen, presented full-screen via a pull-down gesture on
/// `ContentView`'s queue. Mirrors option 6b in the Claude Design mockup
/// ("WSPT To Do App UI" project, turn 6) for the title field, importance
/// pills, live preview, and "Add to queue" button — the mockup's discrete
/// time pills are swapped for a plain numeric field per follow-up feedback,
/// since a fixed set of presets couldn't express an arbitrary estimate.
struct AddTodoForm: View {
    /// The current open (not-done) tasks, for the live "slots in at #N"
    /// preview below — passed in rather than queried here so this view
    /// stays a plain function of its inputs.
    let existingOpenItems: [TodoItem]
    var onAdd: (_ title: String, _ minutes: Double, _ importance: Importance) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool

    @State private var title: String = ""
    @State private var minutesText: String = "30"
    @State private var importance: Importance = .normal
    /// A fixed id for the in-progress draft, so repeated reads of
    /// `draftItem` (a computed property) still refer to "the same" item when
    /// looked up inside `rankedWithDraft` — `TodoItem.init` defaults to a
    /// fresh `UUID()` per call otherwise, which would never match.
    @State private var draftID = UUID()

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var minutes: Double { Double(minutesText) ?? 0 }

    /// Nil once the title and time are both valid; otherwise the reason
    /// "Add to queue" is disabled — shown in place of the preview card, the
    /// same validation-message pattern the rest of the app uses.
    private var validationMessage: String? {
        if trimmedTitle.isEmpty { return "Enter a task name first." }
        if minutes <= 0 { return "Enter an estimated time greater than zero." }
        return nil
    }

    private var canAdd: Bool { validationMessage == nil }

    /// The task being previewed, using a placeholder name when the field is
    /// still empty so the rank/score preview has something to show before
    /// the user types.
    private var draftItem: TodoItem {
        TodoItem(
            id: draftID,
            title: trimmedTitle.isEmpty ? "New task" : trimmedTitle,
            estimatedMinutes: minutes,
            importance: importance
        )
    }

    private var rankedWithDraft: [TodoItem] {
        PriorityScorer.rank(existingOpenItems + [draftItem])
    }

    private var draftIndex: Int {
        rankedWithDraft.firstIndex(where: { $0.id == draftItem.id }) ?? 0
    }

    private var draftScore: Double {
        PriorityScorer.score(for: draftItem)
    }

    /// "above X, below Y" — X is the task this one would outrank (now just
    /// below it in the list), Y is the task it would still rank under (just
    /// above it). Mirrors the mockup's explanatory line.
    private var neighborText: String {
        let below = draftIndex < rankedWithDraft.count - 1 ? rankedWithDraft[draftIndex + 1] : nil
        let above = draftIndex > 0 ? rankedWithDraft[draftIndex - 1] : nil
        var parts: [String] = []
        if let below { parts.append("above \(below.title)") }
        if let above { parts.append("below \(above.title)") }
        return parts.isEmpty ? "The only task in the queue." : parts.joined(separator: ", ") + "."
    }

    private var formulaText: String {
        "\(importance.rawValue) ÷ (2 × \(IOSPriorityTheme.hoursLabel(minutes))) = \(IOSPriorityTheme.formattedScore(draftScore))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                titleField

                VStack(alignment: .leading, spacing: 26) {
                    timeField
                    presetSection(
                        label: "Importance",
                        value: "\(importance.rawValue)",
                        values: Importance.allCases.map(\.rawValue),
                        selected: importance.rawValue,
                        pillLabel: { "\($0)" },
                        onSelect: { importance = Importance(rawValue: $0) ?? .normal }
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 26)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 22)
                        .padding(.top, 32)
                } else {
                    previewCard
                        .padding(.top, 32)

                    Text(attributedExplanation)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .fixedSize(horizontal: false, vertical: true)
                }

                addButton
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                    .padding(.bottom, 30)
            }
        }
        .background(IOSPriorityTheme.background.ignoresSafeArea())
        .onAppear { titleFocused = true }
    }

    private var attributedExplanation: String { "\(formulaText) — \(neighborText)" }

    private var topBar: some View {
        HStack {
            Text("New task")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button("Cancel") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(IOSPriorityTheme.cancelAccent)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 22)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(
                "",
                text: $title,
                prompt: Text("Task name").foregroundStyle(.white.opacity(0.3))
            )
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .tint(IOSPriorityTheme.accent)
            .focused($titleFocused)
            .submitLabel(.done)

            Rectangle()
                .fill(.white.opacity(0.14))
                .frame(height: 1)
                .padding(.top, 16)
        }
        .padding(.horizontal, 22)
    }

    /// A free-form number field for the estimate, replacing the mockup's
    /// discrete minute pills — a fixed preset set can't express an
    /// arbitrary time, so the user just types it.
    private var timeField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))
            HStack(spacing: 8) {
                TextField("30", text: $minutesText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .tint(IOSPriorityTheme.accent)
                Text("min")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func presetSection(
        label: String,
        value: String,
        values: [Int],
        selected: Int,
        pillLabel: @escaping (Int) -> String,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(label: label, value: value)
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { option in
                    pill(pillLabel(option), isSelected: option == selected) {
                        onSelect(option)
                    }
                }
            }
        }
    }

    private func sectionHeader(label: String, value: String) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func pill(_ text: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(isSelected ? IOSPriorityTheme.accent : Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }

    /// The "slots in at #N" band — full-bleed like the queue rows, not
    /// inset like the rest of this screen, matching the mockup.
    private var previewCard: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Slots in at #\(draftIndex + 1)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.7))
                Text(draftItem.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(IOSPriorityTheme.minutesLabel(minutes)) · Importance \(importance.rawValue)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 12)
            Text(IOSPriorityTheme.formattedScore(draftScore))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 18)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(IOSPriorityTheme.previewCard)
    }

    private var addButton: some View {
        Button(action: submit) {
            Text("Add to queue")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .background(IOSPriorityTheme.accent)
        .clipShape(Capsule())
        .opacity(canAdd ? 1 : 0.4)
        .disabled(!canAdd)
    }

    private func submit() {
        guard canAdd else { return }
        onAdd(trimmedTitle, minutes, importance)
        dismiss()
    }
}

#Preview {
    AddTodoForm(existingOpenItems: [], onAdd: { _, _, _ in })
}
#endif
