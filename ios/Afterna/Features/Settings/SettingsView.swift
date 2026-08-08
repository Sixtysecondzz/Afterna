import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var showCredits = false
    @State private var confirmSignOut = false

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("Name", value: container.auth.displayName ?? "Guest")
                if let email = container.auth.email {
                    LabeledContent("Email", value: email)
                }
                Button("Sign out", role: .destructive) {
                    confirmSignOut = true
                }
            }

            Section("Credits") {
                LabeledContent("Balance", value: "\(container.credits.creditBalance) credits")
                LabeledContent("Time left", value: "\(container.credits.availableMinutes) min")
                LabeledContent("Per credit", value: "\(container.credits.minutesPerCredit) min")
                Button("Earn credit (watch ad)") {
                    showCredits = true
                }
                .tint(DesignTokens.accent)
            }

            Section("Support") {
                if let mail = URL(string: "mailto:fisherluke1993@gmail.com?subject=Afterna%20feedback") {
                    Link(destination: mail) {
                        Label("Send feedback", systemImage: "envelope")
                    }
                    .tint(DesignTokens.accent)
                }
                LabeledContent("Version", value: appVersion)
            }

            Section {
                Text("Recordings are transcribed to create your memories. Audio is not kept after processing unless you choose to keep it, and you can delete any memory at any time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Privacy")
            }

            Section("Diagnostics") {
                LabeledContent(
                    "Auth",
                    value: container.auth.userId == "demo"
                        ? "Guest"
                        : (AuthConfig.isSupabaseConfigured ? "Supabase" : "Local")
                )
                LabeledContent("API", value: APIConfig.baseURLString)
                LabeledContent("Upload", value: container.usesMockUpload ? "Mock" : "Live")
            }
        }
        .scrollContentBackground(.hidden)
        .background(DesignTokens.paper)
        .navigationTitle("Settings")
        .sheet(isPresented: $showCredits) {
            CreditsSheet()
        }
        .confirmationDialog(
            "Sign out of Afterna? Memories synced to your account stay safe; local-only data remains on this device.",
            isPresented: $confirmSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                Task { await container.auth.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
