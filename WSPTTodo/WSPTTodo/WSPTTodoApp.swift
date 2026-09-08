import SwiftUI
import SwiftData

@main
struct WSPTTodoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 480, height: 620)
        #endif
    }
}

/// A single shared container backed by the private CloudKit database, so
/// todo items sync across a signed-in user's devices. The container
/// identifier here must match `com.apple.developer.icloud-container-identifiers`
/// in `project.yml`'s entitlements block.
///
/// `TodoItemModel` was designed from the start with CloudKit's SwiftData
/// requirements in mind (no unique constraints, every property has a literal
/// default) — see the doc comment on that type — so no schema changes were
/// needed to turn sync on.
let sharedModelContainer: ModelContainer = {
    let schema = Schema([TodoItemModel.self])
    let modelConfiguration = ModelConfiguration(
        schema: schema,
        cloudKitDatabase: .private("iCloud.com.douglassmurray.wspttodo")
    )

    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
