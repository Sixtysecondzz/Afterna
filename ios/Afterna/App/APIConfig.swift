import Foundation

enum APIConfig {
    /// Live Fly API. Override with env `AFTERNA_API_BASE` or Info.plist `AFTERNA_API_BASE`.
    static let defaultBaseURL = "https://afterna.fly.dev"

    static var baseURLString: String {
        if let env = ProcessInfo.processInfo.environment["AFTERNA_API_BASE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "AFTERNA_API_BASE") as? String {
            let trimmed = plist.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return defaultBaseURL
    }

    /// When true, capture uses local mock upload (no network). Default false → live Fly API.
    static var useMockUpload: Bool {
        if let env = ProcessInfo.processInfo.environment["AFTERNA_USE_MOCK_UPLOAD"] {
            return ["1", "true", "yes"].contains(env.lowercased())
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "AFTERNA_USE_MOCK_UPLOAD") as? Bool {
            return plist
        }
        if let str = Bundle.main.object(forInfoDictionaryKey: "AFTERNA_USE_MOCK_UPLOAD") as? String {
            return ["1", "true", "yes"].contains(str.lowercased())
        }
        return false
    }
}
