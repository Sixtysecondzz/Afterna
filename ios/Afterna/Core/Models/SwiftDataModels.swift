import Foundation
import SwiftData

@Model
final class ConversationEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var durationMs: Int
    var statusRaw: String
    var recordingFileName: String?
    var serverRecordingId: UUID?
    var serverConversationId: UUID?
    var jobId: UUID?
    var isPinned: Bool = false
    var folderId: UUID?
    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegmentEntity.conversation)
    var segments: [TranscriptSegmentEntity]
    @Relationship(deleteRule: .cascade, inverse: \QuoteEntity.conversation)
    var quotes: [QuoteEntity]
    @Relationship(deleteRule: .nullify, inverse: \ActionItemEntity.conversation)
    var actionItems: [ActionItemEntity]

    init(
        id: UUID = UUID(),
        title: String = "Untitled conversation",
        createdAt: Date = .now,
        durationMs: Int = 0,
        statusRaw: String = "local",
        recordingFileName: String? = nil,
        isPinned: Bool = false,
        folderId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.durationMs = durationMs
        self.statusRaw = statusRaw
        self.recordingFileName = recordingFileName
        self.isPinned = isPinned
        self.folderId = folderId
        self.segments = []
        self.quotes = []
        self.actionItems = []
    }
}

@Model
final class TranscriptSegmentEntity {
    @Attribute(.unique) var id: UUID
    var speakerLabel: String
    var text: String
    var startMs: Int
    var endMs: Int
    var conversation: ConversationEntity?

    init(id: UUID = UUID(), speakerLabel: String, text: String, startMs: Int, endMs: Int) {
        self.id = id
        self.speakerLabel = speakerLabel
        self.text = text
        self.startMs = startMs
        self.endMs = endMs
    }
}

@Model
final class FolderEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var serverId: UUID?

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, serverId: UUID? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.serverId = serverId ?? id
    }
}

@Model
final class ActionItemEntity {
    @Attribute(.unique) var id: UUID
    var text: String
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var serverId: UUID?
    var conversation: ConversationEntity?

    var status: ActionItemStatus {
        get { ActionItemStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        text: String,
        status: ActionItemStatus = .open,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        dueDate: Date? = nil,
        serverId: UUID? = nil,
        conversation: ConversationEntity? = nil
    ) {
        self.id = id
        self.text = text
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dueDate = dueDate
        self.serverId = serverId ?? id
        self.conversation = conversation
    }
}

enum ActionItemStatus: String, Codable, CaseIterable, Sendable {
    case open, done, dismissed
}

@Model
final class QuoteEntity {
    @Attribute(.unique) var id: UUID
    var text: String
    var speakerLabel: String?
    var startMs: Int?
    var endMs: Int?
    var segmentId: UUID?
    var createdAt: Date
    var serverId: UUID?
    var conversation: ConversationEntity?

    init(
        id: UUID = UUID(),
        text: String,
        speakerLabel: String? = nil,
        startMs: Int? = nil,
        endMs: Int? = nil,
        segmentId: UUID? = nil,
        createdAt: Date = .now,
        serverId: UUID? = nil,
        conversation: ConversationEntity? = nil
    ) {
        self.id = id
        self.text = text
        self.speakerLabel = speakerLabel
        self.startMs = startMs
        self.endMs = endMs
        self.segmentId = segmentId
        self.createdAt = createdAt
        self.serverId = serverId ?? id
        self.conversation = conversation
    }
}
