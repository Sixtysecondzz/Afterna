import SwiftUI

struct RootView: View {
    @Environment(AppContainer.self) private var container
    @State private var selected: AppTab = .capture
    @AppStorage("afterna.hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showWelcome = false

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
                    .onAppear {
                        if !hasSeenWelcome { showWelcome = true }
                    }
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
        .sheet(isPresented: $showWelcome, onDismiss: { hasSeenWelcome = true }) {
            WelcomeSheet()
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
                TodosView()
            }
            .tabItem { Label("To-dos", systemImage: "checklist") }
            .tag(AppTab.todos)

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
    case memories, capture, todos, search, settings
}

/// One-time welcome shown after the first sign-in.
struct WelcomeSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: DesignTokens.spaceL) {
                Spacer()

                Text("Welcome to Afterna")
                    .font(DesignTokens.displayFont)
                    .foregroundStyle(DesignTokens.ink)

                VStack(alignment: .leading, spacing: DesignTokens.spaceM) {
                    welcomeRow(
                        symbol: "mic.fill",
                        title: "Record with live captions",
                        detail: "Tap the mic and watch the conversation transcribe as you speak."
                    )
                    welcomeRow(
                        symbol: "sparkles",
                        title: "Archive for key points",
                        detail: "Archive a session and Afterna writes the summary, key points, and to-dos for you."
                    )
                    welcomeRow(
                        symbol: "gift.fill",
                        title: "\(AdMobConfig.welcomeCredits) free credits to start",
                        detail: "Each credit is \(container.credits.minutesPerCredit) minutes of recording. Earn more anytime by watching a short ad."
                    )
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Start capturing")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                                .fill(DesignTokens.accent)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.spaceL)
        }
        .presentationDetents([.large])
    }

    private func welcomeRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spaceM) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(DesignTokens.accent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(DesignTokens.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
    }
}
