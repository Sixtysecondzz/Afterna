import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var showCredits = false

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

            Section("Credits") {
                LabeledContent("Balance", value: "\(container.credits.creditBalance) credits")
                LabeledContent("Time left", value: "\(container.credits.availableMinutes) min")
                LabeledContent("Per credit", value: "\(container.credits.minutesPerCredit) min")
                Button("Earn credit (watch ad)") {
                    showCredits = true
                }
            }

            Section("About") {
                LabeledContent("App", value: "Afterna")
                LabeledContent(
                    "Auth",
                    value: container.auth.userId == "demo"
                        ? "Guest"
                        : (AuthConfig.isSupabaseConfigured ? "Supabase" : "Local")
                )
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showCredits) {
            CreditsSheet()
        }
    }
}
