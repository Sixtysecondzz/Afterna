import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("Name", value: container.auth.displayName ?? "—")
                if let email = container.auth.email {
                    LabeledContent("Email", value: email)
                }
                Button("Sign out", role: .destructive) {
                    Task { await container.auth.signOut() }
                }
            }

            Section("About") {
                LabeledContent("App", value: "Afterna")
                LabeledContent("Auth", value: AuthConfig.isSupabaseConfigured ? "Supabase" : "Demo")
            }
        }
        .navigationTitle("Settings")
    }
}
