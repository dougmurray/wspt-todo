import SwiftUI

/// Mirrors `.empty-state` in docs/wspt-todo.html (lines 148-155, 322-325).
/// On iOS, colors follow `IOSPriorityTheme`'s fixed dark palette (the "WSPT
/// To Do App UI" mockup's queue screen has no adaptive/light variant);
/// macOS keeps the default secondary/tertiary styling, which already reads
/// correctly against `MacPriorityTheme`'s forced-light background.
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(iconStyle)
            Text("No tasks yet. Add one above to see it ranked.")
                .font(.subheadline)
                .foregroundStyle(textStyle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    #if os(iOS)
    private var iconStyle: Color { .white.opacity(0.3) }
    private var textStyle: Color { .white.opacity(0.45) }
    #else
    private var iconStyle: HierarchicalShapeStyle { .tertiary }
    private var textStyle: HierarchicalShapeStyle { .secondary }
    #endif
}

#Preview {
    EmptyStateView()
}
