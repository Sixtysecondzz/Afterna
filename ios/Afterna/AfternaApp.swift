import SwiftUI
import SwiftData

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
