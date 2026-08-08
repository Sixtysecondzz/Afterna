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
        baseFreeMinutes: 0,
        rewardMinutes: 10,
        maxDailyRewards: 6,
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

public struct StreamingTokenResponse: Codable, Sendable {
    public var token: String
    public var expiresInSeconds: Int
    public var maxSessionDurationSeconds: Int
    public var wsUrl: String
    public var params: [String: StreamingParamValue]
    public var fixture: Bool

    enum CodingKeys: String, CodingKey {
        case token
        case expiresInSeconds = "expires_in_seconds"
        case maxSessionDurationSeconds = "max_session_duration_seconds"
        case wsUrl = "ws_url"
        case params
        case fixture
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = try c.decode(String.self, forKey: .token)
        expiresInSeconds = try c.decodeIfPresent(Int.self, forKey: .expiresInSeconds) ?? 60
        maxSessionDurationSeconds = try c.decodeIfPresent(Int.self, forKey: .maxSessionDurationSeconds) ?? 3600
        wsUrl = try c.decodeIfPresent(String.self, forKey: .wsUrl) ?? "wss://streaming.assemblyai.com/v3/ws"
        params = try c.decodeIfPresent([String: StreamingParamValue].self, forKey: .params) ?? [:]
        fixture = try c.decodeIfPresent(Bool.self, forKey: .fixture) ?? false
    }
}

public enum StreamingParamValue: Codable, Sendable, CustomStringConvertible {
    case string(String)
    case int(Int)
    case bool(Bool)
    case double(Double)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        self = .string(try c.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        }
    }

    public var description: String {
        switch self {
        case .string(let v): return v
        case .int(let v): return String(v)
        case .bool(let v): return v ? "true" : "false"
        case .double(let v): return String(v)
        }
    }
}

public struct ArchiveSegmentPayload: Codable, Sendable {
    public var speakerLabel: String
    public var text: String
    public var startMs: Int
    public var endMs: Int
    public var confidence: Double?

    public init(speakerLabel: String, text: String, startMs: Int, endMs: Int, confidence: Double? = nil) {
        self.speakerLabel = speakerLabel
        self.text = text
        self.startMs = startMs
        self.endMs = endMs
        self.confidence = confidence
    }

    enum CodingKeys: String, CodingKey {
        case speakerLabel = "speaker_label"
        case text
        case startMs = "start_ms"
        case endMs = "end_ms"
        case confidence
    }
}

/// `GET /v1/conversations/:id/transcript` — segments, summary (with key points), and action items.
public struct ConversationTranscriptResponse: Codable, Sendable {
    public var conversationId: String
    public var status: String?
    public var segments: [Segment]
    public var summary: Summary?
    public var actionItems: [ActionItem]

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case status, segments, summary
        case actionItems = "action_items"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conversationId = try c.decode(String.self, forKey: .conversationId)
        status = try? c.decodeIfPresent(String.self, forKey: .status)
        segments = (try? c.decodeIfPresent([Segment].self, forKey: .segments)) ?? []
        summary = try? c.decodeIfPresent(Summary.self, forKey: .summary)
        actionItems = (try? c.decodeIfPresent([ActionItem].self, forKey: .actionItems)) ?? []
    }

    public struct Segment: Codable, Sendable {
        public var id: String?
        public var text: String
        public var tStartMs: Int
        public var tEndMs: Int
        /// Set in memory/fixture mode.
        public var speakerLabel: String?
        /// Set in Supabase mode via the speakers join.
        public var speakers: SpeakerRef?

        public struct SpeakerRef: Codable, Sendable {
            public var label: String?
        }

        enum CodingKeys: String, CodingKey {
            case id, text, speakers
            case tStartMs = "t_start_ms"
            case tEndMs = "t_end_ms"
            case speakerLabel = "speaker_label"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try? c.decodeIfPresent(String.self, forKey: .id)
            text = (try? c.decodeIfPresent(String.self, forKey: .text)) ?? ""
            tStartMs = (try? c.decodeIfPresent(Int.self, forKey: .tStartMs)) ?? 0
            tEndMs = (try? c.decodeIfPresent(Int.self, forKey: .tEndMs)) ?? 0
            speakerLabel = try? c.decodeIfPresent(String.self, forKey: .speakerLabel)
            speakers = try? c.decodeIfPresent(SpeakerRef.self, forKey: .speakers)
        }

        public var resolvedSpeaker: String {
            speakerLabel ?? speakers?.label ?? "A"
        }
    }

    public struct Summary: Codable, Sendable {
        public var summary: String?
        public var keyPoints: [String]
        public var decisions: [String]

        enum CodingKeys: String, CodingKey {
            case summary
            case keyPoints = "key_points"
            case decisions
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            summary = try? c.decodeIfPresent(String.self, forKey: .summary)
            keyPoints = ((try? c.decodeIfPresent([TextOrObject].self, forKey: .keyPoints)) ?? nil)?
                .compactMap(\.text) ?? []
            decisions = ((try? c.decodeIfPresent([TextOrObject].self, forKey: .decisions)) ?? nil)?
                .compactMap(\.text) ?? []
        }
    }

    /// The extract model returns key points as strings but decisions as `{ text, decided_by, … }` objects.
    /// This wrapper accepts either shape.
    public struct TextOrObject: Codable, Sendable {
        public var text: String?

        public init(from decoder: Decoder) throws {
            if let single = try? decoder.singleValueContainer(), let str = try? single.decode(String.self) {
                text = str
                return
            }
            let c = try? decoder.container(keyedBy: CodingKeys.self)
            text = try? c?.decodeIfPresent(String.self, forKey: .text)
        }

        enum CodingKeys: String, CodingKey { case text }
    }

    public struct ActionItem: Codable, Sendable {
        public var id: String?
        public var text: String
        public var status: String?
        public var dueDate: String?

        enum CodingKeys: String, CodingKey {
            case id, text, status
            case dueDate = "due_date"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try? c.decodeIfPresent(String.self, forKey: .id)
            text = (try? c.decodeIfPresent(String.self, forKey: .text)) ?? ""
            status = try? c.decodeIfPresent(String.self, forKey: .status)
            dueDate = try? c.decodeIfPresent(String.self, forKey: .dueDate)
        }
    }
}

public struct ArchiveLiveResponse: Codable, Sendable {
    public var recordingId: UUID
    public var conversationId: UUID
    public var extractJobId: UUID?
    public var status: String
    public var title: String?
    public var message: String?

    enum CodingKeys: String, CodingKey {
        case recordingId = "recording_id"
        case conversationId = "conversation_id"
        case extractJobId = "extract_job_id"
        case status, title, message
    }
}
