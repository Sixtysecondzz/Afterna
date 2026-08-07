import SwiftUI
import SwiftData

@main
struct AfternaApp: App {
    @State private var container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AdMobBootstrap.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .modelContainer(container.modelContainer)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                AppOpenAdManager.shared.showAdIfAvailable()
            }
        }
    }
}
