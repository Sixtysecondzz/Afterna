import AuthenticationServices
import Foundation
import GoogleSignIn
import Observation

@Observable
@MainActor
final class AuthService {
    enum Status: Equatable {
        case loading
        case signedOut
        case signedIn
    }

    private(set) var status: Status = .loading
    private(set) var displayName: String?
    private(set) var email: String?
    private(set) var userId: String?
    var lastError: String?

    let tokenStore = KeychainTokenStore()
    private var client: SupabaseAuthClient?

    init() {
        if AuthConfig.isSupabaseConfigured,
           let url = URL(string: AuthConfig.supabaseURL) {
            client = SupabaseAuthClient(baseURL: url, anonKey: AuthConfig.supabaseAnonKey)
        }
        if AuthConfig.isGoogleConfigured {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: AuthConfig.googleIOSClientID)
        }
    }

    func bootstrap() async {
        lastError = nil
        guard let client else {
            if let token = await tokenStore.accessToken(), !token.isEmpty {
                status = .signedIn
                displayName = token == "dev-user" ? "Demo User" : "Signed in"
            } else {
                status = .signedOut
            }
            return
        }

        guard let token = await tokenStore.accessToken(), !token.isEmpty, token != "dev-user" else {
            status = .signedOut
            return
        }

        do {
            let user = try await client.user(accessToken: token)
            userId = user.id
            email = user.email
            displayName = user.userMetadata?["full_name"]?.stringValue ?? user.email ?? "Afterna user"
            status = .signedIn
        } catch {
            tokenStore.clear()
            status = .signedOut
        }
    }

    func signInWithApple(idToken: String, fullName: PersonNameComponents?) async {
        lastError = nil
        guard let client else {
            lastError = "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY."
            return
        }
        do {
            let session = try await client.signInWithIdToken(provider: "apple", idToken: idToken)
            if let fullName {
                let formatted = PersonNameComponentsFormatter().string(from: fullName)
                if !formatted.isEmpty {
                    try? await client.updateUserMetadata(
                        accessToken: session.accessToken,
                        data: ["full_name": formatted]
                    )
                }
            }
            apply(session: session)
            status = .signedIn
        } catch {
            lastError = error.localizedDescription
            status = .signedOut
        }
    }

    func signInWithGoogle() async {
        lastError = nil
        guard AuthConfig.isGoogleConfigured else {
            lastError = "Google Sign-In is not configured. Add GIDClientID (iOS OAuth client)."
            return
        }
        guard let client else {
            lastError = "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY."
            return
        }
        guard let presenter = UIKitPresenter.topViewController() else {
            lastError = "Could not find a window to present Google Sign-In."
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                lastError = "Google did not return an ID token."
                return
            }
            let accessToken = result.user.accessToken.tokenString
            let session = try await client.signInWithIdToken(
                provider: "google",
                idToken: idToken,
                accessToken: accessToken
            )
            apply(session: session)
            status = .signedIn
        } catch {
            let ns = error as NSError
            if ns.domain == "com.google.GIDSignIn", ns.code == -5 {
                lastError = nil
            } else {
                lastError = error.localizedDescription
            }
        }
    }

    func continueAsDemo() async {
        tokenStore.save(accessToken: "dev-user", refreshToken: nil, userId: "demo")
        displayName = "Demo User"
        email = nil
        userId = "demo"
        status = .signedIn
        lastError = nil
    }

    func signOut() async {
        if let client, let token = await tokenStore.accessToken(), token != "dev-user" {
            try? await client.signOut(accessToken: token)
        }
        GIDSignIn.sharedInstance.signOut()
        tokenStore.clear()
        displayName = nil
        email = nil
        userId = nil
        status = .signedOut
    }

    private func apply(session: SupabaseSession) {
        tokenStore.save(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userId: session.user.id
        )
        userId = session.user.id
        email = session.user.email
        displayName = session.user.userMetadata?["full_name"]?.stringValue
            ?? session.user.email
            ?? "Afterna user"
    }
}
