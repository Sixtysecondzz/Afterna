import SwiftUI

struct RootView: View {
    @Environment(AppContainer.self) private var container
    @State private var selected: AppTab = .capture

    var body: some View {
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
        }
        .tint(DesignTokens.accent)
        .task {
            await container.flags.refresh(using: container.api)
        }
    }
}

enum AppTab: Hashable {
    case memories, capture, search
}
