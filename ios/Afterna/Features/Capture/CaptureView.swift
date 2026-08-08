import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CaptureView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var sessionId = UUID()
    @State private var isRecording = false
    @State private var statusText = "Ready when you are"
    @State private var statusIsError = false
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
    /// Local draft saved the moment recording stops — survives tab switches / kills.
    @State private var draftEntity: ConversationEntity?
    @State private var userNotes = ""
    @State private var meetingTemplate: MeetingTemplate = .general

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 20) {
                Text("Afterna")
                    .font(DesignTokens.displayFont)
                    .foregroundStyle(DesignTokens.ink)
                    .accessibilityAddTraits(.isHeader)

                Text("\(container.credits.creditBalance) credits · \(container.credits.availableMinutes) min left")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                // Calendar awareness: upcoming meetings → auto-title on archive
                UpcomingMeetingBanner(calendar: container.calendar)

                Text(statusText)
                    .font(DesignTokens.bodyFont)
                    .foregroundStyle(statusIsError ? DesignTokens.error : Color.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                captionsPanel

                if isRecording || canArchive {
                    notesField
                }

                Button {
                    Task { await toggleRecording() }
                } label: {
                    Circle()
                        .fill(isRecording ? Color.red.opacity(0.85) : DesignTokens.accent)
                        .frame(width: 96, height: 96)
                        .scaleEffect(pulse && isRecording ? 1.08 : 1.0)
                        .shadow(
                            color: (isRecording ? Color.red : DesignTokens.accent).opacity(0.35),
                            radius: 18,
                            y: 6
                        )
                        .overlay {
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                }
                .buttonStyle(.plain)
                .disabled(isArchiving)
                .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")

                if !isRecording {
                    templatePicker
                }

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
                    .disabled(isArchiving || (finalTurns.isEmpty && draftEntity == nil))
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Archive and extract key points")

                    if draftEntity != nil {
                        Text("Draft saved in Memories — safe if you leave this screen.")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
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
            Task { await container.calendar.prepareForCapture() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard isRecording else { return }
            if phase == .background || phase == .inactive {
                setStatus("Recording in background — keep going")
            } else if phase == .active {
                setStatus("Listening…")
            }
        }
    }

    private var captionsPanel: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if finalTurns.isEmpty && partialText.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.and.mic")
                            .font(.title2)
                            .foregroundStyle(DesignTokens.textSecondary)
                        Text(isRecording ? "Listening — captions appear here as you speak" : "Live captions appear here when you record")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
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

    private var notesField: some View {
        TextField("Live notes (optional)", text: $userNotes, axis: .vertical)
            .lineLimit(2...4)
            .font(.footnote)
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 8)
            .disabled(isArchiving)
            .accessibilityLabel("Live notes")
            .onChange(of: userNotes) { _, newValue in
                guard let draft = draftEntity else { return }
                draft.userNotes = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : newValue
                try? modelContext.save()
            }
    }

    private var templatePicker: some View {
        HStack(spacing: 8) {
            Text("Template")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Picker("Template", selection: $meetingTemplate) {
                ForEach(MeetingTemplate.allCases) { template in
                    Text(template.label).tag(template)
                }
            }
            .pickerStyle(.menu)
            .tint(DesignTokens.accent)
        }
        .padding(.horizontal, 24)
        .disabled(isArchiving)
        .onChange(of: meetingTemplate) { _, newValue in
            guard let draft = draftEntity else { return }
            draft.meetingTemplate = newValue.rawValue
            try? modelContext.save()
        }
    }

    @MainActor
    private func setStatus(_ text: String, isError: Bool = false) {
        statusText = text
        statusIsError = isError
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
            setStatus("Out of credits — watch an ad to earn more", isError: true)
            showCredits = true
            return
        }
        let allowed = await container.audio.requestPermission()
        guard allowed else {
            setStatus("Microphone permission is required", isError: true)
            return
        }

        sessionId = UUID()
        finalTurns = []
        partialText = ""
        canArchive = false
        processingItem = nil
        draftEntity = nil
        userNotes = ""

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
                        if isRecording { setStatus(message) }
                    }
                }
            )

            container.audio.onPCMChunk = { data in
                Task { await streamClient.sendPCM(data) }
            }
            _ = try container.audio.start(sessionId: sessionId)
            isRecording = true
            setStatus("Listening…")
            Haptics.impact()
        } catch {
            setStatus("Could not start: \(error.localizedDescription)", isError: true)
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
            Haptics.impact(.light)

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
                setStatus("No speech captured — try again", isError: true)
                canArchive = false
            } else {
                saveDraftFromCaptions()
                setStatus("Draft saved — Archive for key points when ready")
                canArchive = true
            }
        } catch {
            setStatus("Could not finish recording: \(error.localizedDescription)", isError: true)
            isRecording = false
            container.audio.onPCMChunk = nil
            await streamClient.stop()
        }
    }

    /// Writes a local draft conversation + segments the moment recording stops.
    @MainActor
    private func saveDraftFromCaptions() {
        let turns = finalTurns
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !turns.isEmpty else { return }

        let title = container.calendar.selectedTitle
            ?? "Conversation \(Date.now.formatted(date: .abbreviated, time: .shortened))"
        let entity: ConversationEntity
        if let existing = draftEntity {
            entity = existing
            entity.title = title
            entity.durationMs = lastDurationMs
            entity.statusRaw = "draft"
            entity.clientSessionId = sessionId
            for old in entity.segments {
                modelContext.delete(old)
            }
        } else {
            entity = ConversationEntity(
                title: title,
                durationMs: lastDurationMs,
                statusRaw: "draft",
                recordingFileName: nil
            )
            entity.clientSessionId = sessionId
            modelContext.insert(entity)
            draftEntity = entity
        }
        let trimmedNotes = userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.userNotes = trimmedNotes.isEmpty ? nil : trimmedNotes
        entity.meetingTemplate = meetingTemplate.rawValue

        for turn in turns {
            let row = TranscriptSegmentEntity(
                speakerLabel: turn.speakerLabel,
                text: turn.text,
                startMs: turn.startMs,
                endMs: max(turn.endMs, turn.startMs)
            )
            row.conversation = entity
            modelContext.insert(row)
        }
        try? modelContext.save()
    }

    @MainActor
    private func archiveLiveSession() async {
        if draftEntity == nil, !finalTurns.isEmpty {
            saveDraftFromCaptions()
        }
        guard let entity = draftEntity else { return }

        let segments: [ArchiveSegmentPayload]
        if !finalTurns.isEmpty {
            segments = finalTurns
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
        } else {
            segments = entity.segments
                .sorted { $0.startMs < $1.startMs }
                .map {
                    ArchiveSegmentPayload(
                        speakerLabel: $0.speakerLabel,
                        text: $0.text,
                        startMs: $0.startMs,
                        endMs: max($0.endMs, $0.startMs),
                        confidence: nil
                    )
                }
        }
        guard !segments.isEmpty else { return }

        isArchiving = true
        setStatus("Archiving…")
        entity.statusRaw = "processing"
        if let calendarTitle = container.calendar.selectedTitle {
            entity.title = calendarTitle
        }
        let trimmedNotes = userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesPayload = trimmedNotes.isEmpty ? nil : trimmedNotes
        entity.userNotes = notesPayload
        entity.meetingTemplate = meetingTemplate.rawValue
        try? modelContext.save()
        defer { isArchiving = false }

        let archiveSessionId = entity.clientSessionId ?? sessionId

        do {
            if container.usesMockUpload {
                entity.statusRaw = "succeeded"
                try? modelContext.save()
                setStatus("Archived (mock) — open Memories for details")
                canArchive = false
                draftEntity = nil
                Haptics.success()
                showInterstitialAfterDelay()
                return
            }

            let response = try await container.api.archiveLiveTranscript(
                clientSessionId: archiveSessionId,
                durationMs: entity.durationMs,
                title: entity.title,
                language: "en",
                segments: segments,
                userNotes: notesPayload,
                template: meetingTemplate.rawValue
            )
            entity.serverRecordingId = response.recordingId
            entity.serverConversationId = response.conversationId
            entity.jobId = response.extractJobId
            entity.statusRaw = "succeeded"
            if let remoteTitle = response.title, !remoteTitle.isEmpty {
                entity.title = remoteTitle
            }
            try? modelContext.save()

            setStatus("Archived — key points are generating")
            canArchive = false
            draftEntity = nil
            Haptics.success()
            showInterstitialAfterDelay()

            if let extractId = response.extractJobId {
                await pollExtract(extractId, entity: entity)
            }
        } catch {
            entity.statusRaw = "draft"
            try? modelContext.save()
            setStatus("Archive failed: \(error.localizedDescription)", isError: true)
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
                setStatus("Out of credits — watch an ad to earn more", isError: true)
                showCredits = true
                return
            }

            setStatus("Uploading audio for transcription…")
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
                setStatus("Import ready (mock)")
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
            setStatus("Import queued — transcription running")
        } catch {
            setStatus("Import failed: \(error.localizedDescription)", isError: true)
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

    /// Shows the post-archive interstitial only after the success status has been visible ~1.5 s.
    private func showInterstitialAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            InterstitialAdManager.shared.showAfterCaptureSaved()
        }
    }

    @MainActor
    private func pollExtract(_ jobId: UUID, entity: ConversationEntity) async {
        for _ in 0..<40 {
            do {
                let status = try await container.api.jobStatus(id: jobId)
                if status.status == "succeeded" {
                    await container.memoryOrg.hydrateFromServer(entity, api: container.api, modelContext: modelContext)
                    setStatus("Archived — key points ready in Memories")
                    return
                }
                if status.status == "failed" || status.status == "dead" {
                    setStatus(status.error ?? "Key points failed — you can retry from the memory", isError: true)
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
                    await container.memoryOrg.hydrateFromServer(entity, api: container.api, modelContext: modelContext)
                    setStatus("Transcribed — open it in Memories")
                    Haptics.success()
                    return
                }
                if status.status == "failed" || status.status == "dead" {
                    setStatus(status.error ?? "Transcription failed", isError: true)
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

enum MeetingTemplate: String, CaseIterable, Identifiable, Sendable {
    case general
    case oneOnOne = "one_on_one"
    case standup
    case sales
    case interview

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return "General"
        case .oneOnOne: return "1:1"
        case .standup: return "Standup"
        case .sales: return "Sales"
        case .interview: return "Interview"
        }
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
