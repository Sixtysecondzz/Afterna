import SwiftUI
import SwiftData
import ConversationCore

@main
struct AfternaApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .modelContainer(container.modelContainer)
        }
    }
}
