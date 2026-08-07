# Transcription Architecture — Afterna

**Companion doc:** `TRANSCRIPTION_RESEARCH.md`  
**Goal:** Production-ready, swappable transcription for an iPhone conversation memory app — **batch post-recording first**, streaming optional later.

---

## Design principles

1. **Provider-agnostic domain model** — app code never imports AssemblyAI/OpenAI/Deepgram types outside adapter modules.  
2. **Batch is the MVP happy path** — record → upload → job → normalize → persist.  
3. **Failover is a product feature** — primary failure or SLA breach routes to fallback without UI rewrite.  
4. **Idempotent jobs** — same `recordingId` never double-bills.  
5. **Normalize early** — store one canonical transcript schema regardless of vendor.  
6. **On-device is assistive** — Apple Speech / WhisperKit may draft; cloud (or future local diarisation) owns “memory truth” for multi-speaker.

---

## High-level flow (MVP)

```
┌─────────────┐   mic + file    ┌──────────────────┐
│  iOS App    │ ──────────────► │ Local Recording  │
│  (SwiftUI)  │                 │ Store (encrypted)│
└──────┬──────┘                 └────────┬─────────┘
       │                                 │
       │ optional on-device draft         │ compress + checksum
       ▼                                 ▼
┌──────────────────┐            ┌────────────────────────┐
│ AppleSpeechDraft │            │ Upload to App Backend  │
│ (SpeechAnalyzer /│            │ (presigned URL / API)  │
│  SFSpeech*)      │            └───────────┬────────────┘
└──────────────────┘                        │
                                            ▼
                               ┌────────────────────────────┐
                               │ Transcription Orchestrator │
                               │  - pick provider           │
                               │  - enqueue job             │
                               │  - retry / failover        │
                               └───────────┬────────────────┘
                         ┌─────────────────┼─────────────────┐
                         ▼                 ▼                 ▼
                  ┌────────────┐   ┌────────────┐   ┌────────────┐
                  │ AssemblyAI │   │   OpenAI   │   │  Deepgram  │
                  │  Adapter   │   │  Adapter   │   │  Adapter   │
                  └──────┬─────┘   └──────┬─────┘   └──────┬─────┘
                         └─────────────────┼─────────────────┘
                                           ▼
                               ┌────────────────────────────┐
                               │ Canonical Transcript Store │
                               │ + speaker map + embeddings │
                               └──────────────┬─────────────┘
                                              ▼
                                         Push / sync
                                              ▼
                                         iOS Memory UI
```

**Recommendation:** Run the orchestrator on a **small backend** (not only on-device). Keeps API keys off the phone, enables webhooks, retries when the app is killed, and centralizes failover.

---

## Recommended provider roles

| Role | Provider | Model / mode |
|---|---|---|
| Primary | AssemblyAI | `universal-3-pro` async + diarization |
| Fallback | OpenAI | `gpt-4o-transcribe-diarize` (multi-speaker) / `gpt-transcribe` (solo) |
| Alternate / future stream | Deepgram | Nova-3 pre-recorded (MVP eval); streaming later |
| On-device draft | Apple | `SpeechAnalyzer` (iOS 26+) / limited `SFSpeechRecognizer` |

See research doc for pricing and capability tradeoffs.

---

## Canonical domain model

Normalize every vendor response into these types (Swift shown; mirror in backend TypeScript/Go as needed).

```swift
import Foundation

/// Stable app-level identity for a captured conversation.
struct RecordingID: Hashable, Codable, Sendable {
    let uuid: UUID
}

enum TranscriptLanguage: String, Codable, Sendable {
    case enAU = "en_au"
    case enUS = "en_us"
    case enGB = "en_gb"
    case auto
    case other
}

struct TranscriptionRequest: Sendable {
    let recordingId: RecordingID
    /// HTTPS URL or signed object storage reference the provider/backend can fetch.
    let audioURL: URL
    let duration: Duration
    let languageHint: TranscriptLanguage
    let expectedSpeakerCount: Int?          // 2 for typical 1:1 memory
    let knownSpeakerHints: [KnownSpeakerHint]
    let vocabularyBoost: [String]           // names, places, product terms
    let requireDiarization: Bool
    let requireWordTimestamps: Bool
    let clientChecksum: String              // sha256 of local file for idempotency
}

struct KnownSpeakerHint: Sendable {
    let speakerId: String                   // app person id
    let displayName: String
    /// Optional short reference clip URL for providers that support enrollment (e.g. OpenAI diarize).
    let referenceAudioURL: URL?
}

struct TranscriptSegment: Codable, Sendable, Identifiable {
    let id: UUID
    let speakerLabel: String                // "A", "B" or provider "speaker_0"
    let speakerPersonId: String?            // resolved app identity if known
    let text: String
    let startMs: Int
    let endMs: Int
    let confidence: Double?
}

struct TranscriptWord: Codable, Sendable {
    let text: String
    let startMs: Int
    let endMs: Int
    let speakerLabel: String?
    let confidence: Double?
}

struct CanonicalTranscript: Codable, Sendable {
    let recordingId: RecordingID
    let provider: TranscriptionProviderID
    let model: String
    let language: String
    let fullText: String
    let segments: [TranscriptSegment]
    let words: [TranscriptWord]             // empty if provider couldn't supply
    let durationMs: Int
    let createdAt: Date
    let rawArtifactURI: String?             // stored vendor JSON for debug/replay
}

enum TranscriptionJobState: Codable, Sendable {
    case queued
    case uploading
    case processing
    case succeeded(CanonicalTranscript)
    case failed(TranscriptionError)
    case cancelled
}

enum TranscriptionProviderID: String, Codable, Sendable, CaseIterable {
    case assemblyAI
    case openAI
    case deepgram
    case google
    case appleOnDevice
    case whisperSelfHosted
}

struct TranscriptionError: Error, Codable, Sendable {
    enum Code: String, Codable, Sendable {
        case unsupportedFeature
        case invalidAudio
        case providerUnavailable
        case rateLimited
        case timeout
        case auth
        case permanentFailure
        case cancelled
    }
    let code: Code
    let message: String
    let retryable: Bool
    let provider: TranscriptionProviderID?
}
```

---

## Swift protocol concept (swappable providers)

### Core protocol

```swift
import Foundation

/// Capability flags so the orchestrator can skip incompatible providers
/// without try/catch archaeology.
struct TranscriptionCapabilities: Sendable {
    var supportsBatch: Bool
    var supportsStreaming: Bool
    var supportsDiarization: Bool
    var supportsWordTimestamps: Bool
    var supportsKnownSpeakerEnrollment: Bool
    var maxUploadBytes: Int?
    var languages: Set<String>
}

protocol TranscriptionProviding: Sendable {
    var id: TranscriptionProviderID { get }
    var capabilities: TranscriptionCapabilities { get }

    /// Submit async batch job. Returns opaque provider job id.
    func startBatch(_ request: TranscriptionRequest) async throws -> ProviderJobHandle

    /// Poll or await completion. Prefer webhook-driven updates on the server;
    /// clients may still poll a status endpoint.
    func fetchBatch(job: ProviderJobHandle) async throws -> TranscriptionJobState

    /// Cancel if the provider supports it (best-effort).
    func cancel(job: ProviderJobHandle) async throws

    /// Map vendor payload → canonical model (also used when replaying webhooks).
    func normalize(rawPayload: Data, request: TranscriptionRequest) throws -> CanonicalTranscript
}

struct ProviderJobHandle: Codable, Sendable, Hashable {
    let provider: TranscriptionProviderID
    let externalJobId: String
    let recordingId: RecordingID
}
```

### Optional streaming (Phase 2+)

```swift
protocol StreamingTranscriptionProviding: TranscriptionProviding {
    func stream(
        _ request: StreamingTranscriptionRequest
    ) -> AsyncThrowingStream<StreamingTranscriptEvent, Error>
}

enum StreamingTranscriptEvent: Sendable {
    case partial(text: String, speakerLabel: String?)
    case finalSegment(TranscriptSegment)
    case speechStarted
    case speechEnded
    case providerInfo(String)
}
```

**MVP:** implement only `TranscriptionProviding`. Keep streaming protocol ready but unused so cellular + background audio complexity doesn’t block launch.

---

## Orchestrator (failover + policy)

```swift
protocol TranscriptionOrchestrating: Sendable {
    func submit(_ request: TranscriptionRequest) async throws -> ProviderJobHandle
    func status(for recordingId: RecordingID) async throws -> TranscriptionJobState
}

struct ProviderPolicy: Sendable {
    var primary: TranscriptionProviderID
    var fallback: TranscriptionProviderID
    var alternate: TranscriptionProviderID?

    /// Route solo voice memos to cheaper models.
    var singleSpeakerProvider: TranscriptionProviderID?
}

actor TranscriptionOrchestrator: TranscriptionOrchestrating {
    private let providers: [TranscriptionProviderID: any TranscriptionProviding]
    private let policy: ProviderPolicy
    private let store: TranscriptJobStore
    private let maxAttempts = 3

    func submit(_ request: TranscriptionRequest) async throws -> ProviderJobHandle {
        if let existing = await store.existingSuccessfulJob(checksum: request.clientChecksum) {
            return existing
        }

        let order = providerOrder(for: request)
        var lastError: TranscriptionError?

        for providerID in order {
            guard let provider = providers[providerID] else { continue }
            guard provider.capabilities.supportsBatch else { continue }
            if request.requireDiarization && !provider.capabilities.supportsDiarization { continue }
            if request.requireWordTimestamps && !provider.capabilities.supportsWordTimestamps {
                // Soft requirement: still allowed; words[] may be empty.
            }

            do {
                let handle = try await provider.startBatch(request)
                await store.remember(handle: handle, request: request, attempt: 1)
                return handle
            } catch let error as TranscriptionError where error.retryable {
                lastError = error
                continue
            } catch {
                lastError = TranscriptionError(
                    code: .permanentFailure,
                    message: String(describing: error),
                    retryable: false,
                    provider: providerID
                )
                continue
            }
        }

        throw lastError ?? TranscriptionError(
            code: .providerUnavailable,
            message: "All providers failed",
            retryable: true,
            provider: nil
        )
    }

    private func providerOrder(for request: TranscriptionRequest) -> [TranscriptionProviderID] {
        if request.requireDiarization == false,
           let cheap = policy.singleSpeakerProvider {
            return [cheap, policy.primary, policy.fallback]
        }
        return [policy.primary, policy.fallback, policy.alternate].compactMap { $0 }
    }

    func status(for recordingId: RecordingID) async throws -> TranscriptionJobState {
        guard let handle = await store.handle(for: recordingId) else {
            return .failed(TranscriptionError(
                code: .invalidAudio,
                message: "Unknown recording",
                retryable: false,
                provider: nil
            ))
        }
        guard let provider = providers[handle.provider] else {
            return .failed(TranscriptionError(
                code: .providerUnavailable,
                message: "Provider missing",
                retryable: true,
                provider: handle.provider
            ))
        }

        let state = try await provider.fetchBatch(job: handle)

        if case .failed(let err) = state, err.retryable {
            return try await failover(from: handle, error: err)
        }
        if case .succeeded(let transcript) = state {
            await store.persist(transcript)
        }
        return state
    }

    private func failover(
        from failed: ProviderJobHandle,
        error: TranscriptionError
    ) async throws -> TranscriptionJobState {
        // Re-load original request from store; start next provider in policy order.
        // Implementation omitted for brevity — must be idempotent and audited.
        _ = error
        _ = failed
        return .failed(error)
    }
}
```

### Failover rules (production)

| Condition | Action |
|---|---|
| HTTP 429 / 503 / timeout | Retry same provider with exponential backoff (3×), then fallback |
| HTTP 401/403 | Alert ops; do **not** burn fallback quota blindly |
| `unsupportedFeature` | Skip to next provider that advertises the capability |
| WER/DER quality gate fail (async eval) | Soft-failover for that recording; alert if rate > threshold |
| Provider status page red | Temporarily demote primary for N minutes |

---

## Adapter sketch

### AssemblyAI (primary)

```swift
struct AssemblyAITranscriptionProvider: TranscriptionProviding {
    let id = TranscriptionProviderID.assemblyAI
    let apiKey: String
    let baseURL = URL(string: "https://api.assemblyai.com")!

    var capabilities: TranscriptionCapabilities {
        .init(
            supportsBatch: true,
            supportsStreaming: true,
            supportsDiarization: true,
            supportsWordTimestamps: true,
            supportsKnownSpeakerEnrollment: false,
            maxUploadBytes: nil,
            languages: ["en", "en_au", "en_us", "en_gb"] // extend as needed
        )
    }

    func startBatch(_ request: TranscriptionRequest) async throws -> ProviderJobHandle {
        // 1) Ensure audio is reachable (upload to AssemblyAI or pass publicly fetchable URL)
        // 2) POST /v2/transcript with:
        //    speech_models: ["universal-3-pro"]
        //    speaker_labels: true
        //    language_code / language_detection
        //    word_boost / keyterms as available
        // 3) Return job id
        fatalError("Implement with URLSession / async HTTP client")
    }

    func fetchBatch(job: ProviderJobHandle) async throws -> TranscriptionJobState {
        fatalError("Poll GET /v2/transcript/:id or handle webhook")
    }

    func cancel(job: ProviderJobHandle) async throws { /* best-effort */ }

    func normalize(rawPayload: Data, request: TranscriptionRequest) throws -> CanonicalTranscript {
        fatalError("Map utterances[] → TranscriptSegment, words[] → TranscriptWord")
    }
}
```

### OpenAI (fallback)

```swift
struct OpenAITranscriptionProvider: TranscriptionProviding {
    let id = TranscriptionProviderID.openAI
    let apiKey: String

    var capabilities: TranscriptionCapabilities {
        .init(
            supportsBatch: true,
            supportsStreaming: true, // live models — expensive; gate behind feature flag
            supportsDiarization: true, // via gpt-4o-transcribe-diarize
            supportsWordTimestamps: true, // via whisper-1 path; diarize is segment-level
            supportsKnownSpeakerEnrollment: true,
            maxUploadBytes: 25 * 1024 * 1024,
            languages: ["*"]
        )
    }

    func startBatch(_ request: TranscriptionRequest) async throws -> ProviderJobHandle {
        // If duration/file > 25MB: server-side chunk + stitch before/within provider rules.
        // Diarize: model=gpt-4o-transcribe-diarize, response_format=diarized_json,
        //          chunking_strategy=auto for audio > 30s
        // Solo: model=gpt-transcribe
        fatalError("Implement multipart /v1/audio/transcriptions")
    }

    func fetchBatch(job: ProviderJobHandle) async throws -> TranscriptionJobState {
        // OpenAI file transcription is often synchronous HTTP;
        // wrap as immediate success job or internal queue item.
        fatalError("Implement")
    }

    func cancel(job: ProviderJobHandle) async throws {}

    func normalize(rawPayload: Data, request: TranscriptionRequest) throws -> CanonicalTranscript {
        fatalError("Map diarized segments {speaker,start,end,text}")
    }
}
```

### Apple on-device (draft only)

```swift
struct AppleOnDeviceTranscriptionProvider: TranscriptionProviding {
    let id = TranscriptionProviderID.appleOnDevice

    var capabilities: TranscriptionCapabilities {
        .init(
            supportsBatch: true,          // file analysis session
            supportsStreaming: true,      // buffer streaming into analyzer
            supportsDiarization: false,   // honest limitation
            supportsWordTimestamps: true, // where API exposes timing
            supportsKnownSpeakerEnrollment: false,
            maxUploadBytes: nil,
            languages: ["device-dependent"]
        )
    }

    func startBatch(_ request: TranscriptionRequest) async throws -> ProviderJobHandle {
        // iOS 26+: SpeechAnalyzer + SpeechTranscriber over local file
        // Older iOS: SFSpeechURLRecognitionRequest with hard duration limits —
        //            chunk artificially AND mark quality as "draft"
        fatalError("Implement on-device path")
    }

    // ...
}
```

**Important:** If `requireDiarization == true`, orchestrator must **not** select Apple as primary/fallback for final memory.

---

## Backend job machine (recommended)

Even with Swift protocols on-device for drafts, production jobs should be server-driven:

```
recording.uploaded
    → job.queued
    → job.provider_submitted (primary)
    → job.provider_running
    → job.normalized
    → job.speaker_resolved
    → job.ready
       ↘ job.failover_submitted
       ↘ job.failed_terminal
```

**Webhook endpoint:** `/webhooks/transcription/{provider}`  
Verify signatures, load `recordingId` from metadata, call `provider.normalize`, persist, push APNs / sync.

**Idempotency key:** `sha256(audio) + featureFlags` (diarization on/off, model tier).

---

## Audio pipeline (iPhone)

1. **Capture:** `AVAudioEngine` / `AVAudioRecorder`, mono 16 kHz+ (48 kHz record → downsample server-side OK).  
2. **Store encrypted** at rest on device.  
3. **VAD / silence trim** (optional, conservative) to cut billable silence.  
4. **Compress:** AAC `.m4a` or Opus — target quality for speech, not music.  
5. **Checksum** before upload.  
6. **Upload** via resumable/presigned PUT (background `URLSession`).  
7. **Show states:** Recording → Uploading → Transcribing → Ready (draft text may appear earlier from Apple).  
8. **Retention:** User policy for local audio vs cloud audio vs transcript-only.

---

## Feature mapping cheat sheet

| Need | AssemblyAI | OpenAI | Deepgram | Apple |
|---|---|---|---|---|
| Batch MVP | ✅ | ✅ | ✅ | Draft only |
| Diarisation | ✅ cheap add-on | ✅ diarize model | ✅ | ❌ |
| Word timestamps | ✅ | whisper-1 / limited on gpt-* | ✅ | Partial |
| Known speakers | Limited | ✅ reference clips | Limited | ❌ |
| Punctuation | ✅ | ✅ | ✅ smart format | Partial |
| Live captions | Phase 2 | Expensive live models | Excellent | On-device possible |
| Long-form offline | ❌ (cloud) | ❌ | ❌ | ✅ SpeechAnalyzer iOS 26+ |

---

## Configuration

Use a remote config / env matrix so you can flip primary without shipping an app binary:

```json
{
  "transcription": {
    "mode": "batch",
    "primary": "assemblyAI",
    "fallback": "openAI",
    "alternate": "deepgram",
    "singleSpeaker": "openAI",
    "models": {
      "assemblyAI": "universal-3-pro",
      "openAI_multi": "gpt-4o-transcribe-diarize",
      "openAI_solo": "gpt-transcribe",
      "deepgram": "nova-3"
    },
    "features": {
      "requireDiarization": true,
      "requireWordTimestamps": true,
      "onDeviceDraft": true
    },
    "sla": {
      "failoverAfterSeconds": 120,
      "maxProviderAttempts": 3
    }
  }
}
```

---

## Security & privacy

- **Never ship provider API keys in the iOS client** for cloud STT.  
- Encrypt audio in transit (TLS) and at rest (device + object storage KMS).  
- Prefer providers with clear retention controls; disable training opt-in where required.  
- Offer **on-device-only mode** (Apple draft / future local stack) with honest UX: no reliable speaker labels.  
- Log provider job ids + checksums; avoid logging raw audio or full transcripts in plaintext ops logs.  
- GDPR: AssemblyAI EU endpoint / Deepgram EU endpoint / regional GCP as needed — pick one residency story and stick to it.

---

## Testing strategy

| Layer | What |
|---|---|
| Contract tests | Each adapter: fixture vendor JSON → `CanonicalTranscript` snapshot |
| Integration | Sandbox API keys; 30–60s clips; assert diarisation labels exist |
| Eval harness | Offline AU/US/UK noisy corpus; score WER/DER; gate provider promotion |
| Chaos | Kill primary (mock 503); ensure fallback completes same `recordingId` once |
| Cost | Meter per-recording `$` estimate from duration × rate card |

---

## MVP build order

1. Domain types + `TranscriptionProviding` + in-memory fake provider  
2. Backend upload + AssemblyAI adapter + webhook normalize  
3. OpenAI diarize fallback path  
4. iOS upload UX + job status sync  
5. Optional Apple on-device draft (iOS 26+ first)  
6. Deepgram adapter behind config for A/B eval  
7. Only then: streaming captions (Deepgram or AssemblyAI realtime)

---

## Non-goals (MVP)

- Perfect overlapping-speech separation  
- Real-time multi-speaker labels on-device via Apple APIs  
- Self-hosted GPU Whisper as the default path  
- Paying streaming rates for post-hoc memory generation  

---

## Summary

Ship a **batch orchestrator** with a **Swift `TranscriptionProviding` protocol**, **AssemblyAI primary**, **OpenAI fallback**, canonical transcript storage, and honest treatment of **Apple Speech** as draft/offline assist. Keep Deepgram wired as a config-swappable alternate for noisy-room evals and a future streaming mode — without letting streaming complexity define the MVP.
