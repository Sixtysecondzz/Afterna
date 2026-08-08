import Foundation

public protocol TokenStore: Sendable {
    func accessToken() async -> String?
}

public actor APIClient {
    public let baseURL: URL
    private let tokenStore: any TokenStore
    private let session: URLSession

    public init(baseURL: URL, tokenStore: any TokenStore, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
    }

    public func fetchConfig() async throws -> RemoteConfig {
        var request = URLRequest(url: url("v1/config"))
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        try Self.throwIfNeeded(response)
        return try JSONDecoder().decode(RemoteConfig.self, from: data)
    }

    public func presignUpload(
        durationMs: Int?,
        mimeType: String = "audio/mp4",
        byteSize: Int?,
        checksum: String?,
        keepAudio: Bool = false
    ) async throws -> PresignResponse {
        struct Body: Encodable {
            let duration_ms: Int?
            let mime_type: String
            let byte_size: Int?
            let checksum_sha256: String?
            let keep_audio: Bool
            let require_diarization: Bool
        }
        return try await authorizedPost(
            path: "v1/uploads/presign",
            body: Body(
                duration_ms: durationMs,
                mime_type: mimeType,
                byte_size: byteSize,
                checksum_sha256: checksum,
                keep_audio: keepAudio,
                require_diarization: true
            )
        )
    }

    public func completeUpload(
        recordingId: UUID,
        checksum: String?,
        byteSize: Int?,
        durationMs: Int?
    ) async throws -> CompleteUploadResponse {
        struct Body: Encodable {
            let recording_id: UUID
            let checksum_sha256: String?
            let byte_size: Int?
            let duration_ms: Int?
        }
        return try await authorizedPost(
            path: "v1/uploads/complete",
            body: Body(
                recording_id: recordingId,
                checksum_sha256: checksum,
                byte_size: byteSize,
                duration_ms: durationMs
            )
        )
    }

    public func jobStatus(id: UUID) async throws -> JobStatus {
        try await authorizedGet(path: "v1/jobs/\(id.uuidString)")
    }

    public func conversationTranscript(id: UUID) async throws -> ConversationTranscriptResponse {
        // Lowercase so memory/fixture-mode Map lookups (string keys) match server-generated ids.
        try await authorizedGet(path: "v1/conversations/\(id.uuidString.lowercased())/transcript")
    }

    public func ask(question: String, conversationId: UUID?, scope: String = "conversation") async throws -> AskResponse {
        struct Body: Encodable {
            let question: String
            let scope: String
            let conversation_id: UUID?
        }
        return try await authorizedPost(
            path: "v1/ask",
            body: Body(question: question, scope: scope, conversation_id: conversationId)
        )
    }

    public func uploadFile(to uploadURL: URL, fileURL: URL, contentType: String) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.upload(for: request, fromFile: fileURL)
        try Self.throwIfNeeded(response)
    }

    public func streamingToken(
        expiresInSeconds: Int = 60,
        maxSessionDurationSeconds: Int = 3600
    ) async throws -> StreamingTokenResponse {
        struct Body: Encodable {
            let expires_in_seconds: Int
            let max_session_duration_seconds: Int
        }
        return try await authorizedPost(
            path: "v1/streaming/token",
            body: Body(
                expires_in_seconds: expiresInSeconds,
                max_session_duration_seconds: maxSessionDurationSeconds
            )
        )
    }

    public func archiveLiveTranscript(
        clientSessionId: UUID,
        durationMs: Int,
        title: String?,
        language: String = "en",
        segments: [ArchiveSegmentPayload]
    ) async throws -> ArchiveLiveResponse {
        struct Body: Encodable {
            let client_session_id: String
            let duration_ms: Int
            let title: String?
            let language: String
            let segments: [ArchiveSegmentPayload]
        }
        return try await authorizedPost(
            path: "v1/conversations/archive",
            body: Body(
                client_session_id: clientSessionId.uuidString,
                duration_ms: durationMs,
                title: title,
                language: language,
                segments: segments
            )
        )
    }

    private func url(_ path: String) -> URL {
        let trimmed = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        return URL(string: "\(trimmed)/\(path)")!
    }

    private func authorizedGet<T: Decodable>(path: String) async throws -> T {
        var request = URLRequest(url: url(path))
        request.httpMethod = "GET"
        if let token = await tokenStore.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        try Self.throwIfNeeded(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func authorizedPost<Body: Encodable, T: Decodable>(path: String, body: Body) async throws -> T {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await tokenStore.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try Self.throwIfNeeded(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func throwIfNeeded(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode)
        }
    }
}

public enum APIError: Error, Sendable {
    case http(Int)
    case missingToken
}
