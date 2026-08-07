import Foundation

public struct RemoteConfig: Codable, Sendable, Equatable {
    public var baseFreeMinutes: Int
    public var rewardMinutes: Int
    public var maxDailyRewards: Int
    public var bannerEnabled: Bool
    public var nativeFeedInterval: Int
    public var bannerRefreshInterval: Int
    public var aiDailyLimit: Int
    public var adsOnSummaryEnabled: Bool
    public var featureFlags: FeatureFlags

    public struct FeatureFlags: Codable, Sendable, Equatable {
        public var fixtureMode: Bool
        public var askAI: Bool
        public var crossConversationSearch: Bool

        enum CodingKeys: String, CodingKey {
            case fixtureMode = "fixture_mode"
            case askAI = "ask_ai"
            case crossConversationSearch = "cross_conversation_search"
        }
    }

    enum CodingKeys: String, CodingKey {
        case baseFreeMinutes = "base_free_minutes"
        case rewardMinutes = "reward_minutes"
        case maxDailyRewards = "max_daily_rewards"
        case bannerEnabled = "banner_enabled"
        case nativeFeedInterval = "native_feed_interval"
        case bannerRefreshInterval = "banner_refresh_interval"
        case aiDailyLimit = "ai_daily_limit"
        case adsOnSummaryEnabled = "ads_on_summary_enabled"
        case featureFlags = "feature_flags"
    }

    public static let offlineDefaults = RemoteConfig(
        baseFreeMinutes: 60,
        rewardMinutes: 5,
        maxDailyRewards: 3,
        bannerEnabled: false,
        nativeFeedInterval: 8,
        bannerRefreshInterval: 60,
        aiDailyLimit: 30,
        adsOnSummaryEnabled: false,
        featureFlags: .init(fixtureMode: true, askAI: true, crossConversationSearch: true)
    )
}

public enum TranscriptionJobState: String, Codable, Sendable {
    case queued, uploading, processing, succeeded, failed, cancelled
}

public struct CanonicalSegment: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var speakerLabel: String
    public var text: String
    public var startMs: Int
    public var endMs: Int
    public var confidence: Double?
}

public struct CanonicalTranscript: Codable, Sendable, Equatable {
    public var recordingId: String
    public var provider: String
    public var model: String
    public var language: String
    public var fullText: String
    public var segments: [CanonicalSegment]
    public var durationMs: Int
    public var createdAt: String
}

public struct PresignResponse: Codable, Sendable {
    public var recordingId: UUID
    public var conversationId: UUID
    public var storagePath: String
    public var uploadUrl: URL
    public var uploadToken: String?
    public var uploadMode: String
    public var headers: [String: String]?

    enum CodingKeys: String, CodingKey {
        case recordingId = "recording_id"
        case conversationId = "conversation_id"
        case storagePath = "storage_path"
        case uploadUrl = "upload_url"
        case uploadToken = "upload_token"
        case uploadMode = "upload_mode"
        case headers
    }
}

public struct CompleteUploadResponse: Codable, Sendable {
    public var recordingId: UUID
    public var conversationId: UUID
    public var jobId: UUID
    public var jobStatus: String
    public var transcriptionStatus: String
    public var message: String?

    enum CodingKeys: String, CodingKey {
        case recordingId = "recording_id"
        case conversationId = "conversation_id"
        case jobId = "job_id"
        case jobStatus = "job_status"
        case transcriptionStatus = "transcription_status"
        case message
    }
}

public struct JobStatus: Codable, Sendable, Equatable {
    public var id: UUID
    public var jobType: String
    public var status: String
    public var recordingId: UUID?
    public var conversationId: UUID?
    public var provider: String?
    public var model: String?
    public var error: String?

    enum CodingKeys: String, CodingKey {
        case id
        case jobType = "job_type"
        case status
        case recordingId = "recording_id"
        case conversationId = "conversation_id"
        case provider, model, error
    }
}

public struct Citation: Codable, Sendable, Identifiable, Equatable {
    public var id: String { "\(segmentId)-\(tStartMs)" }
    public var conversationId: String
    public var segmentId: String
    public var tStartMs: Int
    public var tEndMs: Int
    public var speakerLabel: String?
    public var quote: String

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case segmentId = "segment_id"
        case tStartMs = "t_start_ms"
        case tEndMs = "t_end_ms"
        case speakerLabel = "speaker_label"
        case quote
    }
}

public struct AskResponse: Codable, Sendable {
    public var id: String
    public var answer: String
    public var citations: [Citation]
    public var model: String?
}
