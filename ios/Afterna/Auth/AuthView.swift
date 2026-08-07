import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @Environment(AppContainer.self) private var container
    @State private var busy = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DesignTokens.paper, DesignTokens.mist],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    Text("Afterna")
                        .font(DesignTokens.displayFont)
                        .foregroundStyle(DesignTokens.ink)
                    Text("Sign in to keep your conversation memory across devices.")
                        .font(DesignTokens.bodyFont)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 14) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        handleApple(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        Task { await run { await container.auth.signInWithGoogle() } }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text("Continue with Google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(DesignTokens.ink)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DesignTokens.mist, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)

                    if !AuthConfig.isSupabaseConfigured {
                        Button("Continue as Demo") {
                            Task { await run { await container.auth.continueAsDemo() } }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignTokens.accent)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 28)

                if busy {
                    ProgressView()
                }

                if let error = container.auth.lastError, !error.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                if !AuthConfig.isSupabaseConfigured {
                    Text("Supabase keys not set yet — Demo mode talks to the local API as `dev-user`.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()
                Spacer()
            }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            let ns = error as NSError
            if ns.code == ASAuthorizationError.canceled.rawValue { return }
            container.auth.lastError = error.localizedDescription
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8)
            else {
                container.auth.lastError = "Apple did not return a valid identity token."
                return
            }
            Task {
                await run {
                    await container.auth.signInWithApple(idToken: idToken, fullName: credential.fullName)
                }
            }
        }
    }

    private func run(_ work: @escaping () async -> Void) async {
        busy = true
        defer { busy = false }
        await work()
    }
}
