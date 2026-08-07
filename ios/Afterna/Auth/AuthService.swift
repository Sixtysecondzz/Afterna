import AuthenticationServices
import Foundation
import Observation
import UIKit

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
    private let webAuthPresenter = WebAuthPresenter()

    init() {
        if AuthConfig.isSupabaseConfigured,
           let url = URL(string: AuthConfig.supabaseURL) {
            client = SupabaseAuthClient(baseURL: url, anonKey: AuthConfig.supabaseAnonKey)
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
        guard let client else {
            lastError = "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY."
            return
        }

        let redirectTo = AuthConfig.oauthRedirectURL
        let pkce = PKCE.generate()

        do {
            let authURL = try await client.oauthAuthorizeURL(
                provider: "google",
                redirectTo: redirectTo,
                codeChallenge: pkce.challenge
            )
            let callbackURL = try await webAuthPresenter.authenticate(
                url: authURL,
                callbackScheme: AuthConfig.oauthCallbackScheme
            )
            let session = try await client.exchangeOAuthCode(
                callbackURL: callbackURL,
                codeVerifier: pkce.verifier
            )
            apply(session: session)
            status = .signedIn
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            lastError = nil
        } catch {
            lastError = error.localizedDescription
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

// MARK: - Browser OAuth (no GoogleSignIn SPM)

@MainActor
final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: AuthAPIError.http(0, "Missing OAuth callback URL"))
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                continuation.resume(throwing: AuthAPIError.http(0, "Could not start Google sign-in browser session"))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}
