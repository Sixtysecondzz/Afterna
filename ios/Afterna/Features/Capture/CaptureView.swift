import SwiftUI
import SwiftData

struct CaptureView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var sessionId = UUID()
    @State private var isRecording = false
    @State private var statusText = "Ready when you are"
    @State private var processingItem: OutboxItem?
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DesignTokens.paper, DesignTokens.mist],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Text("Afterna")
                    .font(DesignTokens.displayFont)
                    .foregroundStyle(DesignTokens.ink)
                    .accessibilityAddTraits(.isHeader)

                Text(statusText)
                    .font(DesignTokens.bodyFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    Task { await toggleRecording() }
                } label: {
                    Circle()
                        .fill(isRecording ? Color.red.opacity(0.85) : DesignTokens.accent)
                        .frame(width: 96, height: 96)
                        .scaleEffect(pulse && isRecording ? 1.08 : 1.0)
                        .overlay {
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")

                if let processingItem {
                    ProcessingStatusView(item: processingItem)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    @MainActor
    private func toggleRecording() async {
        if isRecording {
            do {
                let result = try container.audio.stop()
                isRecording = false
                statusText = "Saving locally…"
                let checksum: String
                if FileManager.default.fileExists(atPath: result.url.path) {
                    checksum = (try? UploadOutbox.sha256Hex(of: result.url)) ?? String(repeating: "0", count: 64)
                } else {
                    // Simulator / stub path without real bytes
                    try Data("afterna-fixture".utf8).write(to: result.url, options: .atomic)
                    checksum = try UploadOutbox.sha256Hex(of: result.url)
                }
                let attrs = try? FileManager.default.attributesOfItem(atPath: result.url.path)
                let byteSize = (attrs?[.size] as? NSNumber)?.intValue ?? 0

                let entity = ConversationEntity(
                    title: "Conversation \(Date.now.formatted(date: .abbreviated, time: .shortened))",
                    durationMs: result.durationMs,
                    statusRaw: "local",
                    recordingFileName: result.url.lastPathComponent
                )
                modelContext.insert(entity)
                try? modelContext.save()

                var item = OutboxItem(
                    localFileURL: result.url,
                    durationMs: result.durationMs,
                    checksumSHA256: checksum,
                    byteSize: byteSize
                )
                statusText = "Uploading for auto-transcription…"
                item = try await container.uploadOutbox.process(item)
                processingItem = item
                entity.statusRaw = item.state.rawValue
                entity.serverRecordingId = item.recordingId
                entity.serverConversationId = item.conversationId
                entity.jobId = item.jobId
                try? modelContext.save()

                if let jobId = item.jobId, !container.usesMockUpload {
                    await pollJob(jobId, entity: entity, item: &item)
                } else {
                    item.state = .succeeded
                    processingItem = item
                    entity.statusRaw = "succeeded"
                    // Seed fixture segments for local detail UX
                    entity.segments = [
                        TranscriptSegmentEntity(speakerLabel: "A", text: "Let's ship the Afterna upload pipeline this week.", startMs: 0, endMs: 4200),
                        TranscriptSegmentEntity(speakerLabel: "B", text: "Agreed — auto-transcribe after complete.", startMs: 4300, endMs: 9100)
                    ]
                    try? modelContext.save()
                    statusText = "Ready — memory saved"
                }
            } catch {
                statusText = "Could not finish recording: \(error.localizedDescription)"
                isRecording = false
            }
        } else {
            let allowed = await container.audio.requestPermission()
            guard allowed else {
                statusText = "Microphone permission is required"
                return
            }
            sessionId = UUID()
            do {
                _ = try container.audio.start(sessionId: sessionId)
                isRecording = true
                #if targetEnvironment(simulator)
                statusText = "Listening… (Simulator may use a fallback tone if mic is unavailable)"
                #else
                statusText = "Listening…"
                #endif
            } catch {
                statusText = "Could not start: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func pollJob(_ jobId: UUID, entity: ConversationEntity, item: inout OutboxItem) async {
        for _ in 0..<60 {
            do {
                let status = try await container.api.jobStatus(id: jobId)
                item.state = TranscriptionJobState(rawValue: status.status == "running" ? "processing" : status.status) ?? .processing
                processingItem = item
                entity.statusRaw = item.state.rawValue
                try? modelContext.save()
                if status.status == "succeeded" {
                    statusText = "Transcribed"
                    return
                }
                if status.status == "failed" || status.status == "dead" {
                    statusText = status.error ?? "Transcription failed"
                    return
                }
            } catch {
                // keep polling
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            // Kick local worker tick in fixture/dev
            _ = try? await container.api.fetchConfig()
            await tickWorker()
        }
    }

    private func tickWorker() async {
        guard let url = URL(string: (ProcessInfo.processInfo.environment["AFTERNA_API_BASE"] ?? "http://127.0.0.1:8787") + "/v1/worker/tick") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        _ = try? await URLSession.shared.data(for: req)
    }
}

struct ProcessingStatusView: View {
    let item: OutboxItem
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ProgressView(value: progress)
                .tint(DesignTokens.accent)
        }
        .padding()
        .frame(maxWidth: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var title: String {
        switch item.state {
        case .queued: return "Queued"
        case .uploading: return "Uploading"
        case .processing: return "Transcribing"
        case .succeeded: return "Ready"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    private var progress: Double {
        switch item.state {
        case .queued: return 0.15
        case .uploading: return 0.4
        case .processing: return 0.75
        case .succeeded: return 1
        case .failed, .cancelled: return 1
        }
    }
}
