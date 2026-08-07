import Foundation

enum AuthConfig {
    /// Supabase project URL, e.g. https://xxxx.supabase.co
    static var supabaseURL: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
            ?? ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? ""
    }

    /// Supabase anon (public) key
    static var supabaseAnonKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
            ?? ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? ""
    }

    /// Custom URL scheme used for Supabase OAuth return (must match Info.plist + Supabase redirect allow-list).
    static var oauthCallbackScheme: String { "app.afterna.ios" }

    static var oauthRedirectURL: String { "\(oauthCallbackScheme)://auth-callback" }

    static var isSupabaseConfigured: Bool {
        let url = supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.hasPrefix("https://") && !key.isEmpty && !key.contains("YOUR_")
    }
}
