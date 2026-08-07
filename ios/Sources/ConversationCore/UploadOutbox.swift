import Foundation
import CryptoKit

public struct OutboxItem: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var localFileURL: URL
    public var durationMs: Int
    public var checksumSHA256: String
    public var byteSize: Int
    public var recordingId: UUID?
    public var conversationId: UUID?
    public var jobId: UUID?
    public var state: TranscriptionJobState
    public var lastError: String?

    public init(
        id: UUID = UUID(),
        localFileURL: URL,
        durationMs: Int,
        checksumSHA256: String,
        byteSize: Int,
        state: TranscriptionJobState = .queued
    ) {
        self.id = id
        self.localFileURL = localFileURL
        self.durationMs = durationMs
        self.checksumSHA256 = checksumSHA256
        self.byteSize = byteSize
        self.state = state
    }
}

public protocol Uploading: Sendable {
    func process(_ item: OutboxItem) async throws -> OutboxItem
}

/// Uploads local AAC → complete → auto-transcribe job (server enqueues AssemblyAI).
public actor UploadOutbox: Uploading {
    private let api: APIClient

    public init(api: APIClient) {
        self.api = api
    }

    public func process(_ item: OutboxItem) async throws -> OutboxItem {
        var next = item
        next.state = .uploading

        let presign = try await api.presignUpload(
            durationMs: item.durationMs,
            mimeType: "audio/mp4",
            byteSize: item.byteSize,
            checksum: item.checksumSHA256,
            keepAudio: false
        )
        next.recordingId = presign.recordingId
        next.conversationId = presign.conversationId

        try await api.uploadFile(to: presign.uploadUrl, fileURL: item.localFileURL, contentType: "audio/mp4")

        let complete = try await api.completeUpload(
            recordingId: presign.recordingId,
            checksum: item.checksumSHA256,
            byteSize: item.byteSize,
            durationMs: item.durationMs
        )
        next.jobId = complete.jobId
        next.state = .processing
        return next
    }

    public static func sha256Hex(of fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Local mock for Phases 0–3 / offline tests without network.
public actor MockUploading: Uploading {
    public init() {}
    public func process(_ item: OutboxItem) async throws -> OutboxItem {
        var next = item
        next.recordingId = UUID()
        next.conversationId = UUID()
        next.jobId = UUID()
        next.state = .processing
        try await Task.sleep(nanoseconds: 200_000_000)
        next.state = .succeeded
        return next
    }
}
