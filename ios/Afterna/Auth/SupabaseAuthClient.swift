import Foundation

struct SupabaseSession: Codable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct SupabaseUser: Codable, Sendable {
    var id: String
    var email: String?
    var userMetadata: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }
}

/// Minimal JSON value for user_metadata without pulling in Extra packages.
enum AnyCodableValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case object([String: AnyCodableValue])
    case array([AnyCodableValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode([String: AnyCodableValue].self) { self = .object(v); return }
        if let v = try? c.decode([AnyCodableValue].self) { self = .array(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        }
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
}

/// Lightweight Supabase Auth client (ID-token sign-in) — no supabase-swift SPM dependency.
actor SupabaseAuthClient {
    private let baseURL: URL
    private let anonKey: String
    private let session: URLSession

    init(baseURL: URL, anonKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.session = session
    }

    func signInWithIdToken(provider: String, idToken: String, accessToken: String? = nil) async throws -> SupabaseSession {
        var comps = URLComponents(url: baseURL.appending(path: "auth/v1/token"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        var body: [String: String] = [
            "provider": provider,
            "id_token": idToken,
        ]
        if let accessToken {
            body["access_token"] = accessToken
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try Self.throwIfNeeded(response, data: data)
        return try JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    func updateUserMetadata(accessToken: String, data: [String: String]) async throws {
        var request = URLRequest(url: baseURL.appending(path: "auth/v1/user"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["data": data])
        let (respData, response) = try await session.data(for: request)
        try Self.throwIfNeeded(response, data: respData)
    }

    func user(accessToken: String) async throws -> SupabaseUser {
        var request = URLRequest(url: baseURL.appending(path: "auth/v1/user"))
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try Self.throwIfNeeded(response, data: data)
        return try JSONDecoder().decode(SupabaseUser.self, from: data)
    }

    func signOut(accessToken: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "auth/v1/logout"))
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try Self.throwIfNeeded(response, data: data)
    }

    private static func throwIfNeeded(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw AuthAPIError.http(http.statusCode, message)
        }
    }
}

enum AuthAPIError: LocalizedError {
    case http(Int, String)
    var errorDescription: String? {
        switch self {
        case .http(let code, let body):
            return "Auth error (\(code)): \(body)"
        }
    }
}
