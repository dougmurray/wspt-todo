#if os(iOS)
import SwiftUI
import WSPTCore

/// The "New task" screen, presented full-screen via a pull-down gesture on
/// `ContentView`'s queue. Mirrors option 6b in the Claude Design mockup
/// ("WSPT To Do App UI" project, turn 6) for the title field, importance
/// pills, and "Add to queue" button — the mockup's discrete time pills are
/// swapped for a plain numeric field per follow-up feedback, since a fixed
/// set of presets couldn't express an arbitrary estimate.
struct AddTodoForm: View {
    /// Non-nil when this screen is editing an existing task (double-tapped
    /// from the queue) rather than creating a new one — switches the title,
    /// button label, and submit action, and seeds the fields/draft id from
    /// its values so the live preview reflects the item being edited.
    var editingItem: TodoItem?
    var onAdd: (_ title: String, _ minutes: Double, _ importance: Importance) -> Void = { _, _, _ in }
    var onSave: (_ title: String, _ minutes: Double, _ importance: Importance) -> Void = { _, _, _ in }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool
    @FocusState private var minutesFocused: Bool

    @State private var title: String
    @State private var minutesText: String
    @State private var importance: Importance
    /// Tracks whether the time field still holds its untouched seed value —
    /// once true, focusing it no longer clears it. Starts `true` when
    /// editing (the seeded value is the task's real estimate, not a
    /// placeholder default), so only the "New task" flow's "30" default
    /// gets cleared on first tap.
    @State private var hasEditedMinutes: Bool

    private var isEditing: Bool { editingItem != nil }

    init(
        editingItem: TodoItem? = nil,
        onAdd: @escaping (_ title: String, _ minutes: Double, _ importance: Importance) -> Void = { _, _, _ in },
        onSave: @escaping (_ title: String, _ minutes: Double, _ importance: Importance) -> Void = { _, _, _ in }
    ) {
        self.editingItem = editingItem
        self.onAdd = onAdd
        self.onSave = onSave
        _title = State(initialValue: editingItem?.title ?? "")
        _minutesText = State(initialValue: editingItem.map { String(Int($0.estimatedMinutes)) } ?? "30")
        _importance = State(initialValue: editingItem?.importance ?? .normal)
        _hasEditedMinutes = State(initialValue: editingItem != nil)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var minutes: Double { Double(minutesText) ?? 0 }

    /// Nil once the title and time are both valid; otherwise the reason
    /// "Add to queue" is disabled.
    private var validationMessage: String? {
        if trimmedTitle.isEmpty { return "Enter a task name first." }
        if minutes <= 0 { return "Enter an estimated time greater than zero." }
        return nil
    }

    private var canAdd: Bool { validationMessage == nil }

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

    private var topBar: some View {
        HStack {
            Text(isEditing ? "Edit task" : "New task")
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
                    .focused($minutesFocused)
                    .onChange(of: minutesFocused) { _, isFocused in
                        if isFocused && !hasEditedMinutes {
                            minutesText = ""
                            hasEditedMinutes = true
                        }
                    }
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

    private var addButton: some View {
        Button(action: submit) {
            Text(isEditing ? "Save changes" : "Add to queue")
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
        if isEditing {
            onSave(trimmedTitle, minutes, importance)
        } else {
            onAdd(trimmedTitle, minutes, importance)
        }
        dismiss()
    }
}

#Preview {
    AddTodoForm(onAdd: { _, _, _ in })
}
#endif
