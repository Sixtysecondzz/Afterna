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

    /// Google Cloud iOS OAuth client ID (…apps.googleusercontent.com)
    static var googleIOSClientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
            ?? ProcessInfo.processInfo.environment["GID_CLIENT_ID"]
            ?? ""
    }

    static var isSupabaseConfigured: Bool {
        let url = supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.hasPrefix("https://") && !key.isEmpty && !key.contains("YOUR_")
    }

    static var isGoogleConfigured: Bool {
        let id = googleIOSClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        return id.contains("apps.googleusercontent.com") && !id.contains("YOUR_")
    }
}
