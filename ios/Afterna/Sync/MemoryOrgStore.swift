import Foundation
import Observation
import SwiftData

/// Syncs folders, todos, quotes, and pin/folder flags with Supabase when signed in.
@Observable
@MainActor
final class MemoryOrgStore {
    private(set) var lastError: String?
    private(set) var isSyncing = false
    private(set) var requiresSignIn = false

    private let tokenStore: KeychainTokenStore
    private let auth: AuthService
    private var client: SupabaseDataClient?

    init(auth: AuthService, tokenStore: KeychainTokenStore) {
        self.auth = auth
        self.tokenStore = tokenStore
        if AuthConfig.isSupabaseConfigured, let url = URL(string: AuthConfig.supabaseURL) {
            client = SupabaseDataClient(baseURL: url, anonKey: AuthConfig.supabaseAnonKey)
        }
    }

    private func liveCredentials() async throws -> (token: String, userId: UUID, client: SupabaseDataClient) {
        guard let client else { throw DataAPIError.notSignedIn }
        guard let token = await tokenStore.accessToken(), !token.isEmpty, token != "dev-user" else {
            requiresSignIn = true
            throw DataAPIError.notSignedIn
        }
        guard let userIdString = auth.userId, let userId = UUID(uuidString: userIdString) else {
            requiresSignIn = true
            throw DataAPIError.notSignedIn
        }
        requiresSignIn = false
        return (token, userId, client)
    }

    func refreshAll(modelContext: ModelContext) async {
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }
        do {
            let creds = try await liveCredentials()
            let folders = try await creds.client.listFolders(accessToken: creds.token)
            mergeFolders(folders, into: modelContext)

            let actions = try await creds.client.listActionItems(accessToken: creds.token)
            mergeActionItems(actions, into: modelContext)

            let quotes = try await creds.client.listQuotes(accessToken: creds.token)
            mergeQuotes(quotes, into: modelContext)

            let local = try modelContext.fetch(FetchDescriptor<ConversationEntity>())
            let serverIds = local.compactMap(\.serverConversationId)
            if !serverIds.isEmpty {
                let flags = try await creds.client.fetchConversationFlags(ids: serverIds, accessToken: creds.token)
                for conv in local {
                    guard let sid = conv.serverConversationId, let flag = flags[sid] else { continue }
                    conv.isPinned = flag.pinned
                    conv.folderId = flag.folderId
                }
            }
            try? modelContext.save()
        } catch let error as DataAPIError {
            if case .notSignedIn = error {
                requiresSignIn = true
            } else {
                lastError = error.localizedDescription
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Folders

    func createFolder(name: String, modelContext: ModelContext) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let creds = try await liveCredentials()
            let remote = try await creds.client.createFolder(name: trimmed, userId: creds.userId, accessToken: creds.token)
            let entity = FolderEntity(id: remote.id, name: remote.name, createdAt: remote.createdAt ?? .now, serverId: remote.id)
            modelContext.insert(entity)
            try? modelContext.save()
        } catch {
            let entity = FolderEntity(name: trimmed)
            modelContext.insert(entity)
            try? modelContext.save()
            if case .notSignedIn = error as? DataAPIError {
                requiresSignIn = true
            } else {
                lastError = error.localizedDescription
            }
        }
    }

    func renameFolder(_ folder: FolderEntity, name: String, modelContext: ModelContext) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folder.name = trimmed
        try? modelContext.save()
        do {
            let creds = try await liveCredentials()
            let id = folder.serverId ?? folder.id
            try await creds.client.renameFolder(id: id, name: trimmed, accessToken: creds.token)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteFolder(_ folder: FolderEntity, modelContext: ModelContext) async {
        let id = folder.serverId ?? folder.id
        modelContext.delete(folder)
        try? modelContext.save()
        do {
            let creds = try await liveCredentials()
            try await creds.client.deleteFolder(id: id, accessToken: creds.token)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Pin / folder assign

    func togglePin(_ conversation: ConversationEntity, modelContext: ModelContext) async {
        conversation.isPinned.toggle()
        try? modelContext.save()
        guard let serverId = conversation.serverConversationId else { return }
        do {
            let creds = try await liveCredentials()
            try await creds.client.updateConversation(
                id: serverId,
                isPinned: conversation.isPinned,
                folderId: nil,
                accessToken: creds.token
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func assignFolder(_ conversation: ConversationEntity, folderId: UUID?, modelContext: ModelContext) async {
        conversation.folderId = folderId
        try? modelContext.save()
        guard let serverId = conversation.serverConversationId else { return }
        do {
            let creds = try await liveCredentials()
            if let folderId {
                try await creds.client.updateConversation(
                    id: serverId,
                    isPinned: nil,
                    folderId: folderId,
                    accessToken: creds.token
                )
            } else {
                try await creds.client.clearConversationFolder(id: serverId, accessToken: creds.token)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Action items

    func createTodo(text: String, conversation: ConversationEntity?, modelContext: ModelContext) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let creds = try await liveCredentials()
            let remote = try await creds.client.createActionItem(
                text: trimmed,
                userId: creds.userId,
                conversationId: conversation?.serverConversationId,
                accessToken: creds.token
            )
            let entity = ActionItemEntity(
                id: remote.id,
                text: remote.text,
                status: ActionItemStatus(rawValue: remote.status) ?? .open,
                createdAt: remote.createdAt ?? .now,
                updatedAt: remote.updatedAt ?? .now,
                serverId: remote.id,
                conversation: conversation
            )
            modelContext.insert(entity)
            try? modelContext.save()
        } catch {
            // Local fallback for guest / offline
            let entity = ActionItemEntity(text: trimmed, conversation: conversation)
            modelContext.insert(entity)
            try? modelContext.save()
            if case .notSignedIn = error as? DataAPIError {
                requiresSignIn = true
            } else {
                lastError = error.localizedDescription
            }
        }
    }

    func setTodoStatus(_ item: ActionItemEntity, status: ActionItemStatus, modelContext: ModelContext) async {
        item.status = status
        item.updatedAt = .now
        try? modelContext.save()
        guard let serverId = item.serverId else { return }
        do {
            let creds = try await liveCredentials()
            try await creds.client.updateActionItemStatus(id: serverId, status: status.rawValue, accessToken: creds.token)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteTodo(_ item: ActionItemEntity, modelContext: ModelContext) async {
        let serverId = item.serverId
        modelContext.delete(item)
        try? modelContext.save()
        guard let serverId else { return }
        do {
            let creds = try await liveCredentials()
            try await creds.client.deleteActionItem(id: serverId, accessToken: creds.token)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Quotes

    func saveQuote(
        from segment: TranscriptSegmentEntity,
        conversation: ConversationEntity,
        modelContext: ModelContext
    ) async {
        do {
            let creds = try await liveCredentials()
            guard let serverConversationId = conversation.serverConversationId else {
                // Local-only memory: store locally
                let q = QuoteEntity(
                    text: segment.text,
                    speakerLabel: segment.speakerLabel,
                    startMs: segment.startMs,
                    endMs: segment.endMs,
                    segmentId: segment.id,
                    conversation: conversation
                )
                modelContext.insert(q)
                try? modelContext.save()
                return
            }
            let remote = try await creds.client.createQuote(
                userId: creds.userId,
                conversationId: serverConversationId,
                text: segment.text,
                speakerLabel: segment.speakerLabel,
                segmentId: nil,
                tStartMs: segment.startMs,
                tEndMs: segment.endMs,
                accessToken: creds.token
            )
            let q = QuoteEntity(
                id: remote.id,
                text: remote.text,
                speakerLabel: remote.speakerLabel,
                startMs: remote.tStartMs,
                endMs: remote.tEndMs,
                segmentId: remote.segmentId,
                createdAt: remote.createdAt ?? .now,
                serverId: remote.id,
                conversation: conversation
            )
            modelContext.insert(q)
            try? modelContext.save()
        } catch {
            let q = QuoteEntity(
                text: segment.text,
                speakerLabel: segment.speakerLabel,
                startMs: segment.startMs,
                endMs: segment.endMs,
                segmentId: segment.id,
                conversation: conversation
            )
            modelContext.insert(q)
            try? modelContext.save()
            lastError = error.localizedDescription
        }
    }

    func deleteQuote(_ quote: QuoteEntity, modelContext: ModelContext) async {
        let serverId = quote.serverId
        modelContext.delete(quote)
        try? modelContext.save()
        guard let serverId else { return }
        do {
            let creds = try await liveCredentials()
            try await creds.client.deleteQuote(id: serverId, accessToken: creds.token)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Merge helpers

    private func mergeFolders(_ remote: [RemoteFolder], into context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<FolderEntity>())) ?? []
        var byServer: [UUID: FolderEntity] = [:]
        for f in existing {
            if let sid = f.serverId { byServer[sid] = f }
            byServer[f.id] = f
        }
        var seen = Set<UUID>()
        for r in remote {
            seen.insert(r.id)
            if let local = byServer[r.id] {
                local.name = r.name
                local.serverId = r.id
            } else {
                context.insert(FolderEntity(id: r.id, name: r.name, createdAt: r.createdAt ?? .now, serverId: r.id))
            }
        }
        for f in existing {
            let sid = f.serverId ?? f.id
            if !seen.contains(sid) {
                context.delete(f)
            }
        }
    }

    private func mergeActionItems(_ remote: [RemoteActionItem], into context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ActionItemEntity>())) ?? []
        var byServer: [UUID: ActionItemEntity] = [:]
        for a in existing {
            if let sid = a.serverId { byServer[sid] = a }
            byServer[a.id] = a
        }
        let conversations = (try? context.fetch(FetchDescriptor<ConversationEntity>())) ?? []
        var convByServer: [UUID: ConversationEntity] = [:]
        for c in conversations {
            if let sid = c.serverConversationId { convByServer[sid] = c }
        }
        var seen = Set<UUID>()
        for r in remote {
            seen.insert(r.id)
            let conv = r.conversationId.flatMap { convByServer[$0] }
            if let local = byServer[r.id] {
                local.text = r.text
                local.statusRaw = r.status
                local.serverId = r.id
                local.conversation = conv
                local.updatedAt = r.updatedAt ?? local.updatedAt
            } else {
                context.insert(
                    ActionItemEntity(
                        id: r.id,
                        text: r.text,
                        status: ActionItemStatus(rawValue: r.status) ?? .open,
                        createdAt: r.createdAt ?? .now,
                        updatedAt: r.updatedAt ?? .now,
                        serverId: r.id,
                        conversation: conv
                    )
                )
            }
        }
        for a in existing where a.serverId != nil {
            let sid = a.serverId ?? a.id
            if !seen.contains(sid) {
                context.delete(a)
            }
        }
    }

    private func mergeQuotes(_ remote: [RemoteQuote], into context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<QuoteEntity>())) ?? []
        var byServer: [UUID: QuoteEntity] = [:]
        for q in existing {
            if let sid = q.serverId { byServer[sid] = q }
            byServer[q.id] = q
        }
        let conversations = (try? context.fetch(FetchDescriptor<ConversationEntity>())) ?? []
        var convByServer: [UUID: ConversationEntity] = [:]
        for c in conversations {
            if let sid = c.serverConversationId { convByServer[sid] = c }
        }
        var seen = Set<UUID>()
        for r in remote {
            seen.insert(r.id)
            let conv = convByServer[r.conversationId]
            if let local = byServer[r.id] {
                local.text = r.text
                local.speakerLabel = r.speakerLabel
                local.startMs = r.tStartMs
                local.endMs = r.tEndMs
                local.serverId = r.id
                local.conversation = conv
            } else if let conv {
                context.insert(
                    QuoteEntity(
                        id: r.id,
                        text: r.text,
                        speakerLabel: r.speakerLabel,
                        startMs: r.tStartMs,
                        endMs: r.tEndMs,
                        segmentId: r.segmentId,
                        createdAt: r.createdAt ?? .now,
                        serverId: r.id,
                        conversation: conv
                    )
                )
            }
        }
        for q in existing where q.serverId != nil {
            let sid = q.serverId ?? q.id
            if !seen.contains(sid) {
                context.delete(q)
            }
        }
    }
}

extension DataAPIError: Equatable {
    static func == (lhs: DataAPIError, rhs: DataAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.notSignedIn, .notSignedIn), (.missingRow, .missingRow): return true
        case (.http(let a, _), .http(let b, _)): return a == b
        default: return false
        }
    }
}
