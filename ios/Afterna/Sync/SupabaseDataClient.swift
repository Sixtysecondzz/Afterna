import Foundation

struct RemoteFolder: Codable, Identifiable, Sendable, Equatable {
    var id: UUID
    var userId: UUID
    var name: String
    var parentId: UUID?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case userId = "user_id"
        case parentId = "parent_id"
        case createdAt = "created_at"
    }
}

struct RemoteActionItem: Codable, Identifiable, Sendable, Equatable {
    var id: UUID
    var userId: UUID
    var conversationId: UUID?
    var text: String
    var status: String
    var dueDate: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, text, status
        case userId = "user_id"
        case conversationId = "conversation_id"
        case dueDate = "due_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RemoteQuote: Codable, Identifiable, Sendable, Equatable {
    var id: UUID
    var userId: UUID
    var conversationId: UUID
    var segmentId: UUID?
    var text: String
    var speakerLabel: String?
    var tStartMs: Int?
    var tEndMs: Int?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, text
        case userId = "user_id"
        case conversationId = "conversation_id"
        case segmentId = "segment_id"
        case speakerLabel = "speaker_label"
        case tStartMs = "t_start_ms"
        case tEndMs = "t_end_ms"
        case createdAt = "created_at"
    }
}

/// PostgREST client for folders / action_items / quotes / conversation pin+folder.
actor SupabaseDataClient {
    private let baseURL: URL
    private let anonKey: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, anonKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let d = ISO8601DateFormatter().date(from: s) { return d }
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: s) { return d }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date \(s)")
        }
        self.decoder = decoder
        self.encoder = JSONEncoder()
    }

    // MARK: Folders

    func listFolders(accessToken: String) async throws -> [RemoteFolder] {
        try await get("folders", query: "select=*&order=name.asc", accessToken: accessToken)
    }

    func createFolder(name: String, userId: UUID, accessToken: String) async throws -> RemoteFolder {
        struct Body: Encodable {
            var name: String
            var user_id: UUID
        }
        let rows: [RemoteFolder] = try await post(
            "folders",
            body: Body(name: name, user_id: userId),
            accessToken: accessToken,
            prefer: "return=representation"
        )
        guard let row = rows.first else { throw DataAPIError.missingRow }
        return row
    }

    func renameFolder(id: UUID, name: String, accessToken: String) async throws {
        struct Body: Encodable { var name: String }
        try await sendPatch("folders", query: "id=eq.\(id.uuidString)", body: Body(name: name), accessToken: accessToken)
    }

    func deleteFolder(id: UUID, accessToken: String) async throws {
        try await delete("folders", query: "id=eq.\(id.uuidString)", accessToken: accessToken)
    }

    // MARK: Conversations (pin / folder)

    func updateConversation(
        id: UUID,
        isPinned: Bool?,
        folderId: UUID?,
        accessToken: String
    ) async throws {
        // Encode null folder explicitly when clearing — use separate payload
        if let folderId {
            struct Body: Encodable {
                var is_pinned: Bool?
                var folder_id: UUID
            }
            try await sendPatch(
                "conversations",
                query: "id=eq.\(id.uuidString)",
                body: Body(is_pinned: isPinned, folder_id: folderId),
                accessToken: accessToken
            )
        } else if let isPinned {
            struct Body: Encodable { var is_pinned: Bool }
            try await sendPatch(
                "conversations",
                query: "id=eq.\(id.uuidString)",
                body: Body(is_pinned: isPinned),
                accessToken: accessToken
            )
        }
    }

    func clearConversationFolder(id: UUID, accessToken: String) async throws {
        // PostgREST null: send JSON null
        let data = Data(#"{"folder_id":null}"#.utf8)
        try await rawPatch("conversations", query: "id=eq.\(id.uuidString)", data: data, accessToken: accessToken)
    }

    func fetchConversationFlags(ids: [UUID], accessToken: String) async throws -> [UUID: (pinned: Bool, folderId: UUID?)] {
        guard !ids.isEmpty else { return [:] }
        let list = ids.map(\.uuidString).joined(separator: ",")
        struct Row: Codable {
            var id: UUID
            var is_pinned: Bool?
            var folder_id: UUID?
        }
        let rows: [Row] = try await get(
            "conversations",
            query: "select=id,is_pinned,folder_id&id=in.(\(list))",
            accessToken: accessToken
        )
        var map: [UUID: (Bool, UUID?)] = [:]
        for r in rows {
            map[r.id] = (r.is_pinned ?? false, r.folder_id)
        }
        return map
    }

    // MARK: Action items

    func listActionItems(accessToken: String, conversationId: UUID? = nil) async throws -> [RemoteActionItem] {
        var q = "select=*&order=created_at.desc"
        if let conversationId {
            q += "&conversation_id=eq.\(conversationId.uuidString)"
        }
        return try await get("action_items", query: q, accessToken: accessToken)
    }

    func createActionItem(
        text: String,
        userId: UUID,
        conversationId: UUID?,
        accessToken: String
    ) async throws -> RemoteActionItem {
        struct Body: Encodable {
            var text: String
            var user_id: UUID
            var conversation_id: UUID?
            var status: String
        }
        let rows: [RemoteActionItem] = try await post(
            "action_items",
            body: Body(text: text, user_id: userId, conversation_id: conversationId, status: "open"),
            accessToken: accessToken,
            prefer: "return=representation"
        )
        guard let row = rows.first else { throw DataAPIError.missingRow }
        return row
    }

    func updateActionItemStatus(id: UUID, status: String, accessToken: String) async throws {
        struct Body: Encodable {
            var status: String
            var updated_at: String
        }
        let now = ISO8601DateFormatter().string(from: Date())
        try await sendPatch(
            "action_items",
            query: "id=eq.\(id.uuidString)",
            body: Body(status: status, updated_at: now),
            accessToken: accessToken
        )
    }

    func updateActionItemText(id: UUID, text: String, accessToken: String) async throws {
        struct Body: Encodable {
            var text: String
            var updated_at: String
        }
        let now = ISO8601DateFormatter().string(from: Date())
        try await sendPatch(
            "action_items",
            query: "id=eq.\(id.uuidString)",
            body: Body(text: text, updated_at: now),
            accessToken: accessToken
        )
    }

    func deleteActionItem(id: UUID, accessToken: String) async throws {
        try await delete("action_items", query: "id=eq.\(id.uuidString)", accessToken: accessToken)
    }

    // MARK: Quotes

    func listQuotes(accessToken: String, conversationId: UUID? = nil) async throws -> [RemoteQuote] {
        var q = "select=*&order=created_at.desc"
        if let conversationId {
            q += "&conversation_id=eq.\(conversationId.uuidString)"
        }
        return try await get("quotes", query: q, accessToken: accessToken)
    }

    func createQuote(
        userId: UUID,
        conversationId: UUID,
        text: String,
        speakerLabel: String?,
        segmentId: UUID?,
        tStartMs: Int?,
        tEndMs: Int?,
        accessToken: String
    ) async throws -> RemoteQuote {
        struct Body: Encodable {
            var user_id: UUID
            var conversation_id: UUID
            var text: String
            var speaker_label: String?
            var segment_id: UUID?
            var t_start_ms: Int?
            var t_end_ms: Int?
        }
        let rows: [RemoteQuote] = try await post(
            "quotes",
            body: Body(
                user_id: userId,
                conversation_id: conversationId,
                text: text,
                speaker_label: speakerLabel,
                segment_id: segmentId,
                t_start_ms: tStartMs,
                t_end_ms: tEndMs
            ),
            accessToken: accessToken,
            prefer: "return=representation"
        )
        guard let row = rows.first else { throw DataAPIError.missingRow }
        return row
    }

    func deleteQuote(id: UUID, accessToken: String) async throws {
        try await delete("quotes", query: "id=eq.\(id.uuidString)", accessToken: accessToken)
    }

    // MARK: HTTP

    private func get<T: Decodable>(_ table: String, query: String, accessToken: String) async throws -> T {
        var comps = URLComponents(url: restURL(table), resolvingAgainstBaseURL: false)!
        comps.query = query
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        applyHeaders(&request, accessToken: accessToken)
        let (data, response) = try await session.data(for: request)
        try throwIfNeeded(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func post<Body: Encodable, T: Decodable>(
        _ table: String,
        body: Body,
        accessToken: String,
        prefer: String
    ) async throws -> T {
        var request = URLRequest(url: restURL(table))
        request.httpMethod = "POST"
        applyHeaders(&request, accessToken: accessToken)
        request.setValue(prefer, forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: request)
        try throwIfNeeded(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func sendPatch<Body: Encodable>(_ table: String, query: String, body: Body, accessToken: String) async throws {
        var comps = URLComponents(url: restURL(table), resolvingAgainstBaseURL: false)!
        comps.query = query
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "PATCH"
        applyHeaders(&request, accessToken: accessToken)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: request)
        try throwIfNeeded(response, data: data)
    }

    private func rawPatch(_ table: String, query: String, data: Data, accessToken: String) async throws {
        var comps = URLComponents(url: restURL(table), resolvingAgainstBaseURL: false)!
        comps.query = query
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "PATCH"
        applyHeaders(&request, accessToken: accessToken)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = data
        let (respData, response) = try await session.data(for: request)
        try throwIfNeeded(response, data: respData)
    }

    private func delete(_ table: String, query: String, accessToken: String) async throws {
        var comps = URLComponents(url: restURL(table), resolvingAgainstBaseURL: false)!
        comps.query = query
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "DELETE"
        applyHeaders(&request, accessToken: accessToken)
        let (data, response) = try await session.data(for: request)
        try throwIfNeeded(response, data: data)
    }

    private func restURL(_ table: String) -> URL {
        baseURL.appending(path: "rest/v1/\(table)")
    }

    private func applyHeaders(_ request: inout URLRequest, accessToken: String) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }

    private func throwIfNeeded(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw DataAPIError.http(http.statusCode, body)
        }
    }
}

enum DataAPIError: LocalizedError {
    case http(Int, String)
    case missingRow
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .http(let code, let body): return "Sync error (\(code)): \(body)"
        case .missingRow: return "Server returned no row"
        case .notSignedIn: return "Sign in to sync folders, todos, quotes, and pins."
        }
    }
}
