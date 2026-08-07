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
    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegmentEntity.conversation)
    var segments: [TranscriptSegmentEntity]

    init(
        id: UUID = UUID(),
        title: String = "Untitled conversation",
        createdAt: Date = .now,
        durationMs: Int = 0,
        statusRaw: String = "local",
        recordingFileName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.durationMs = durationMs
        self.statusRaw = statusRaw
        self.recordingFileName = recordingFileName
        self.segments = []
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
