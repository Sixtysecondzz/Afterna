import AuthenticationServices
import Foundation
import GoogleSignIn
import Observation
import Supabase

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
    private var supabase: SupabaseClient?

    init() {
        if AuthConfig.isSupabaseConfigured,
           let url = URL(string: AuthConfig.supabaseURL) {
            supabase = SupabaseClient(supabaseURL: url, supabaseKey: AuthConfig.supabaseAnonKey)
        }
        if AuthConfig.isGoogleConfigured {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: AuthConfig.googleIOSClientID)
        }
    }

    func bootstrap() async {
        lastError = nil
        guard let supabase else {
            // No Supabase yet — restore demo session if present, else signed out.
            if let token = await tokenStore.accessToken(), !token.isEmpty {
                status = .signedIn
                displayName = token == "dev-user" ? "Demo User" : "Signed in"
            } else {
                status = .signedOut
            }
            return
        }

        do {
            let session = try await supabase.auth.session
            await apply(session: session)
            status = .signedIn
        } catch {
            tokenStore.clear()
            status = .signedOut
        }
    }

    func signInWithApple(idToken: String, fullName: PersonNameComponents?) async {
        lastError = nil
        guard let supabase else {
            lastError = "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY."
            return
        }
        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )
            if let fullName {
                let formatted = PersonNameComponentsFormatter().string(from: fullName)
                if !formatted.isEmpty {
                    _ = try? await supabase.auth.update(
                        user: UserAttributes(data: ["full_name": .string(formatted)])
                    )
                }
            }
            await apply(session: session)
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
        guard let supabase else {
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
            let session = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
            await apply(session: session)
            status = .signedIn
        } catch {
            // User cancel is common — keep message light
            let ns = error as NSError
            if ns.domain == "com.google.GIDSignIn", ns.code == -5 {
                lastError = nil
            } else {
                lastError = error.localizedDescription
            }
        }
    }

    /// Local-only path until Supabase keys are installed (API Bearer dev-user).
    func continueAsDemo() async {
        tokenStore.save(accessToken: "dev-user", refreshToken: nil, userId: "demo")
        displayName = "Demo User"
        email = nil
        userId = "demo"
        status = .signedIn
        lastError = nil
    }

    func signOut() async {
        if let supabase {
            try? await supabase.auth.signOut()
        }
        GIDSignIn.sharedInstance.signOut()
        tokenStore.clear()
        displayName = nil
        email = nil
        userId = nil
        status = .signedOut
    }

    private func apply(session: Session) async {
        tokenStore.save(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userId: session.user.id.uuidString
        )
        userId = session.user.id.uuidString
        email = session.user.email
        displayName = session.user.email ?? "Afterna user"
    }
}
