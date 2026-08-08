import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CaptureView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext

    @State private var sessionId = UUID()
    @State private var isRecording = false
    @State private var statusText = "Ready when you are"
    @State private var pulse = false
    @State private var showCredits = false
    @State private var showImporter = false

    @State private var streamClient = AssemblyAIStreamingClient()
    @State private var finalTurns: [LiveCaptionTurn] = []
    @State private var partialText = ""
    @State private var lastDurationMs = 0
    @State private var canArchive = false
    @State private var isArchiving = false
    @State private var processingItem: OutboxItem?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DesignTokens.paper, DesignTokens.mist],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Afterna")
                    .font(DesignTokens.displayFont)
                    .foregroundStyle(DesignTokens.ink)
                    .accessibilityAddTraits(.isHeader)

                Text("\(container.credits.creditBalance) credits · \(container.credits.availableMinutes) min left")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(statusText)
                    .font(DesignTokens.bodyFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                captionsPanel

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
                .disabled(isArchiving)
                .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")

                if canArchive && !isRecording {
                    Button {
                        Task { await archiveLiveSession() }
                    } label: {
                        Text(isArchiving ? "Archiving…" : "Archive & extract key points")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.accent)
                    .disabled(isArchiving || finalTurns.isEmpty)
                    .padding(.horizontal, 24)
                }

                if !isRecording {
                    HStack(spacing: 20) {
                        Button("Import audio") { showImporter = true }
                        Button("Get more credits") { showCredits = true }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignTokens.accent)
                }

                if let processingItem {
                    ProcessingStatusView(item: processingItem)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCredits) {
            CreditsSheet()
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio, .mpeg4Audio, .wav, UTType(filenameExtension: "mp3")].compactMap { $0 },
            allowsMultipleSelection: false
        ) { result in
            Task { await importAudio(result) }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var captionsPanel: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(finalTurns) { turn in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(turn.speakerLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.accent)
                        Text(turn.text)
                            .font(DesignTokens.bodyFont)
                            .foregroundStyle(DesignTokens.ink)
                    }
                }
                if !partialText.isEmpty {
                    Text(partialText)
                        .font(DesignTokens.bodyFont)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .frame(maxHeight: 220)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 8)
    }

    @MainActor
    private func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    @MainActor
    private func startRecording() async {
        guard container.credits.canStartRecording() else {
            statusText = "Out of credits — watch an ad to earn more"
            showCredits = true
            return
        }
        let allowed = await container.audio.requestPermission()
        guard allowed else {
            statusText = "Microphone permission is required"
            return
        }

        sessionId = UUID()
        finalTurns = []
        partialText = ""
        canArchive = false
        processingItem = nil

        do {
            try await streamClient.start(
                tokenProvider: { [api = container.api] in
                    try await api.streamingToken()
                },
                onTurn: { turn in
                    Task { @MainActor in
                        if turn.isFinal {
                            finalTurns.append(turn)
                            partialText = ""
                        } else {
                            partialText = turn.text
                        }
                    }
                },
                onStatus: { message in
                    Task { @MainActor in
                        if isRecording { statusText = message }
                    }
                }
            )

            container.audio.onPCMChunk = { data in
                Task { await streamClient.sendPCM(data) }
            }
            _ = try container.audio.start(sessionId: sessionId)
            isRecording = true
            statusText = "Listening…"
        } catch {
            statusText = "Could not start: \(error.localizedDescription)"
            await streamClient.stop()
            container.audio.onPCMChunk = nil
        }
    }

    @MainActor
    private func stopRecording() async {
        do {
            let result = try container.audio.stop()
            container.audio.onPCMChunk = nil
            await streamClient.stop()
            isRecording = false
            lastDurationMs = result.durationMs
            container.credits.consume(durationMs: result.durationMs)

            // Promote leftover partial into finals for archive
            if !partialText.isEmpty {
                finalTurns.append(
                    LiveCaptionTurn(
                        id: UUID(),
                        speakerLabel: "A",
                        text: partialText,
                        startMs: lastDurationMs,
                        endMs: lastDurationMs,
                        isFinal: true
                    )
                )
                partialText = ""
            }

            if finalTurns.isEmpty {
                statusText = "No speech captured — try again"
                canArchive = false
            } else {
                statusText = "Stopped — review captions, then Archive"
                canArchive = true
            }
        } catch {
            statusText = "Could not finish recording: \(error.localizedDescription)"
            isRecording = false
            container.audio.onPCMChunk = nil
            await streamClient.stop()
        }
    }

    @MainActor
    private func archiveLiveSession() async {
        guard !finalTurns.isEmpty else { return }
        isArchiving = true
        statusText = "Archiving…"
        defer { isArchiving = false }

        let segments = finalTurns
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map {
                ArchiveSegmentPayload(
                    speakerLabel: $0.speakerLabel,
                    text: $0.text,
                    startMs: $0.startMs,
                    endMs: max($0.endMs, $0.startMs),
                    confidence: nil
                )
            }

        let title = "Conversation \(Date.now.formatted(date: .abbreviated, time: .shortened))"
        let entity = ConversationEntity(
            title: title,
            durationMs: lastDurationMs,
            statusRaw: "processing",
            recordingFileName: nil
        )
        modelContext.insert(entity)
        for seg in segments {
            let row = TranscriptSegmentEntity(
                speakerLabel: seg.speakerLabel,
                text: seg.text,
                startMs: seg.startMs,
                endMs: seg.endMs
            )
            row.conversation = entity
            modelContext.insert(row)
        }
        try? modelContext.save()

        do {
            if container.usesMockUpload {
                entity.statusRaw = "succeeded"
                try? modelContext.save()
                statusText = "Archived (mock) — open Memories for details"
                canArchive = false
                InterstitialAdManager.shared.showAfterCaptureSaved()
                return
            }

            let response = try await container.api.archiveLiveTranscript(
                clientSessionId: sessionId,
                durationMs: lastDurationMs,
                title: title,
                language: "en",
                segments: segments
            )
            entity.serverRecordingId = response.recordingId
            entity.serverConversationId = response.conversationId
            entity.jobId = response.extractJobId
            entity.statusRaw = "succeeded"
            if let remoteTitle = response.title, !remoteTitle.isEmpty {
                entity.title = remoteTitle
            }
            try? modelContext.save()

            if let extractId = response.extractJobId {
                await pollExtract(extractId)
            }
            statusText = "Archived — key points are generating"
            canArchive = false
            InterstitialAdManager.shared.showAfterCaptureSaved()
        } catch {
            entity.statusRaw = "failed"
            try? modelContext.save()
            statusText = "Archive failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func importAudio(_ result: Result<[URL], Error>) async {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            guard container.credits.canStartRecording() else {
                statusText = "Out of credits — watch an ad to earn more"
                showCredits = true
                return
            }

            statusText = "Uploading audio for transcription…"
            let checksum = try UploadOutbox.sha256Hex(of: url)
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let byteSize = (attrs[.size] as? NSNumber)?.intValue ?? 0
            let durationMs = await estimateDurationMs(url)

            let entity = ConversationEntity(
                title: "Import \(Date.now.formatted(date: .abbreviated, time: .shortened))",
                durationMs: durationMs,
                statusRaw: "uploading",
                recordingFileName: url.lastPathComponent
            )
            modelContext.insert(entity)
            try? modelContext.save()

            var item = OutboxItem(
                localFileURL: url,
                durationMs: durationMs,
                checksumSHA256: checksum,
                byteSize: byteSize
            )

            if container.usesMockUpload {
                item = try await container.uploadOutbox.process(item)
                entity.statusRaw = "succeeded"
                entity.segments = [
                    TranscriptSegmentEntity(speakerLabel: "A", text: "Imported fixture transcript.", startMs: 0, endMs: durationMs)
                ]
                try? modelContext.save()
                statusText = "Import ready (mock)"
                return
            }

            item = try await container.uploadOutbox.process(item)
            processingItem = item
            entity.statusRaw = item.state.rawValue
            entity.serverRecordingId = item.recordingId
            entity.serverConversationId = item.conversationId
            entity.jobId = item.jobId
            try? modelContext.save()
            container.credits.consume(durationMs: durationMs)

            if let jobId = item.jobId {
                await pollJob(jobId, entity: entity, item: &item)
            }
            statusText = "Import queued — transcription running"
        } catch {
            statusText = "Import failed: \(error.localizedDescription)"
        }
    }

    private func estimateDurationMs(_ url: URL) async -> Int {
        // Lightweight: use file size heuristic if AVAsset unavailable on background hop
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attrs?[.size] as? NSNumber)?.intValue ?? 0
        // ~16 kbps AAC-ish lower bound → rough minutes; clamp to at least 1s
        let approx = max(bytes / 2000, 1000)
        return min(approx, 3_600_000)
    }

    @MainActor
    private func pollExtract(_ jobId: UUID) async {
        for _ in 0..<40 {
            do {
                let status = try await container.api.jobStatus(id: jobId)
                if status.status == "succeeded" {
                    statusText = "Archived — key points ready"
                    return
                }
                if status.status == "failed" || status.status == "dead" {
                    statusText = status.error ?? "Key points failed"
                    return
                }
            } catch {
                // keep polling
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await tickWorker()
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
            await tickWorker()
        }
    }

    private func tickWorker() async {
        guard let url = URL(string: APIConfig.baseURLString + "/v1/worker/tick") else { return }
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
