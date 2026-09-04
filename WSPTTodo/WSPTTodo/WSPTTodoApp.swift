import SwiftUI
import SwiftData

@main
struct WSPTTodoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: TodoItemModel.self)
        #if os(macOS)
        .defaultSize(width: 480, height: 620)
        #endif
    }
}
