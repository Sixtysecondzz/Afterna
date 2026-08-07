import SwiftUI

struct RootView: View {
    @Environment(AppContainer.self) private var container
    @State private var selected: AppTab = .capture

    var body: some View {
        Group {
            switch container.auth.status {
            case .loading:
                ZStack {
                    DesignTokens.paper.ignoresSafeArea()
                    ProgressView("Afterna")
                }
            case .signedOut:
                AuthView()
            case .signedIn:
                mainTabs
            }
        }
        .task {
            await container.auth.bootstrap()
            if container.auth.status == .signedIn {
                container.bindCreditsToCurrentUser()
                await container.flags.refresh(using: container.api)
            }
        }
        .onChange(of: container.auth.status) { _, status in
            if status == .signedIn {
                container.bindCreditsToCurrentUser()
            }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selected) {
            NavigationStack {
                MemoriesView()
            }
            .tabItem { Label("Memories", systemImage: "books.vertical") }
            .tag(AppTab.memories)

            NavigationStack {
                CaptureView()
            }
            .tabItem { Label("Capture", systemImage: "mic.circle.fill") }
            .tag(AppTab.capture)

            NavigationStack {
                SearchView()
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(AppTab.search)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .tint(DesignTokens.accent)
    }
}

enum AppTab: Hashable {
    case memories, capture, search, settings
}
