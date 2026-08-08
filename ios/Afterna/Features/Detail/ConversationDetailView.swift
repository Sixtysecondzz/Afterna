import SwiftUI
import SwiftData
import UIKit

struct ConversationDetailView: View {
    @Bindable var conversation: ConversationEntity
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var tab: DetailTab = .summary
    @State private var newTodo = ""
    @State private var quoteSavedMessage: String?
    @State private var isHydrating = false

    @State private var showAsk = false
    @State private var askAIEnabled = false
    @State private var crossConversationEnabled = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var quoteToDelete: QuoteEntity?
    @State private var todoToDelete: ActionItemEntity?
    @State private var shareLinkURL: URL?
    @State private var shareLinkError: String?
    @State private var isCreatingShareLink = false
    @State private var isArchivingDraft = false
    @State private var archiveDraftError: String?
    @State private var renameSpeakerFrom: String?
    @State private var renameSpeakerTo = ""

    private var sortedQuotes: [QuoteEntity] {
        conversation.quotes.sorted { $0.createdAt > $1.createdAt }
    }

    private var sortedActions: [ActionItemEntity] {
        conversation.actionItems.sorted { $0.createdAt > $1.createdAt }
    }

    private var sortedSegments: [TranscriptSegmentEntity] {
        conversation.segments.sorted { $0.startMs < $1.startMs }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(DetailTab.allCases, id: \.self) { t in
                    Text(t.title).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch tab {
            case .summary:
                summaryTab
            case .transcript:
                transcriptTab
            case .actions:
                actionsTab
            case .quotes:
                quotesTab
            }
        }
        .background(DesignTokens.paper)
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if askAIEnabled {
                    Button {
                        showAsk = true
                    } label: {
                        Image(systemName: "sparkles")
                    }
                    .disabled(conversation.serverConversationId == nil && !crossConversationEnabled)
                    .accessibilityLabel("Ask AI about this memory")
                }

                ShareLink(item: exportText, subject: Text(conversation.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share transcript and summary")

                Menu {
                    Button {
                        Task { await createAndShareLink() }
                    } label: {
                        Label(
                            isCreatingShareLink ? "Creating link…" : "Copy share link",
                            systemImage: "link"
                        )
                    }
                    .disabled(conversation.serverConversationId == nil || isCreatingShareLink)

                    Button {
                        Task { await container.memoryOrg.togglePin(conversation, modelContext: modelContext) }
                    } label: {
                        Label(conversation.isPinned ? "Unpin" : "Pin", systemImage: conversation.isPinned ? "pin.slash" : "pin")
                    }
                    Button {
                        renameText = conversation.title
                        showRename = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More actions")
            }
        }
        .task {
            let config = container.flags.current()
            askAIEnabled = config.featureFlags.askAI
            crossConversationEnabled = config.featureFlags.crossConversationSearch
            await hydrate()
        }
        .sheet(isPresented: $showAsk) {
            AskAISheet(conversation: conversation)
        }
        .alert("Rename memory", isPresented: $showRename) {
            TextField("Title", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    conversation.title = trimmed
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename speaker", isPresented: Binding(
            get: { renameSpeakerFrom != nil },
            set: { if !$0 { renameSpeakerFrom = nil } }
        )) {
            TextField("Name", text: $renameSpeakerTo)
            Button("Save") {
                Task { await applySpeakerRename() }
            }
            Button("Cancel", role: .cancel) { renameSpeakerFrom = nil }
        } message: {
            Text("All lines labeled Speaker \(renameSpeakerFrom ?? "") will use this name.")
        }
        .confirmationDialog(
            "Delete this pull quote?",
            isPresented: Binding(get: { quoteToDelete != nil }, set: { if !$0 { quoteToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete quote", role: .destructive) {
                if let quote = quoteToDelete {
                    Task { await container.memoryOrg.deleteQuote(quote, modelContext: modelContext) }
                }
                quoteToDelete = nil
            }
            Button("Cancel", role: .cancel) { quoteToDelete = nil }
        }
        .confirmationDialog(
            "Delete this to-do?",
            isPresented: Binding(get: { todoToDelete != nil }, set: { if !$0 { todoToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete to-do", role: .destructive) {
                if let item = todoToDelete {
                    Task { await container.memoryOrg.deleteTodo(item, modelContext: modelContext) }
                }
                todoToDelete = nil
            }
            Button("Cancel", role: .cancel) { todoToDelete = nil }
        }
        .sheet(isPresented: Binding(
            get: { shareLinkURL != nil },
            set: { if !$0 { shareLinkURL = nil } }
        )) {
            if let shareLinkURL {
                ActivityView(activityItems: [shareLinkURL])
            }
        }
        .alert("Couldn’t create share link", isPresented: Binding(
            get: { shareLinkError != nil },
            set: { if !$0 { shareLinkError = nil } }
        )) {
            Button("OK", role: .cancel) { shareLinkError = nil }
        } message: {
            Text(shareLinkError ?? "Try again in a moment.")
        }
        .overlay(alignment: .bottom) {
            if let quoteSavedMessage {
                Text(quoteSavedMessage)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
            }
        }
    }

    private func createAndShareLink() async {
        guard let conversationId = conversation.serverConversationId else {
            shareLinkError = "This memory only exists on this device. Archive it first to create a share link."
            return
        }
        isCreatingShareLink = true
        defer { isCreatingShareLink = false }
        do {
            let created = try await container.api.createShareLink(conversationId: conversationId)
            UIPasteboard.general.string = created.url.absoluteString
            withAnimation {
                quoteSavedMessage = "Share link copied"
            }
            shareLinkURL = created.url
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { quoteSavedMessage = nil }
        } catch {
            shareLinkError = "Check your connection and try again."
        }
    }

    private func hydrate() async {
        guard conversation.serverConversationId != nil else { return }
        isHydrating = true
        defer { isHydrating = false }
        await container.memoryOrg.hydrateFromServer(conversation, api: container.api, modelContext: modelContext)
    }

    @MainActor
    private func applySpeakerRename() async {
        guard let from = renameSpeakerFrom else { return }
        let to = renameSpeakerTo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !to.isEmpty else { return }
        for seg in conversation.segments where seg.speakerLabel == from {
            seg.speakerLabel = to
        }
        for quote in conversation.quotes where quote.speakerLabel == from {
            quote.speakerLabel = to
        }
        try? modelContext.save()
        if let serverId = conversation.serverConversationId {
            try? await container.api.renameSpeaker(
                conversationId: serverId,
                fromLabel: from,
                toName: to
            )
        }
        renameSpeakerFrom = nil
        withAnimation { quoteSavedMessage = "Speaker renamed to \(to)" }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        withAnimation { quoteSavedMessage = nil }
    }

    // MARK: Summary

    private var summaryTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spaceM) {
                HStack(alignment: .top) {
                    Text(conversation.title)
                        .font(DesignTokens.titleFont)
                    Spacer()
                    StatusChip(statusRaw: conversation.statusRaw)
                }

                if conversation.statusRaw == "draft" {
                    draftArchiveCard
                }

                summaryContent

                if !conversation.keyPoints.isEmpty {
                    bulletSection(title: "Key points", items: conversation.keyPoints, symbol: "sparkle")
                }

                if !conversation.decisions.isEmpty {
                    bulletSection(title: "Decisions", items: conversation.decisions, symbol: "checkmark.seal")
                }

                if conversation.summaryText != nil || !conversation.keyPoints.isEmpty {
                    aftermathActions
                }

                if !sortedQuotes.isEmpty {
                    Text("Pull quotes")
                        .font(.headline)
                        .padding(.top, DesignTokens.spaceS)
                    ForEach(sortedQuotes.prefix(5)) { quote in
                        quoteCard(quote)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .refreshable { await hydrate() }
    }

    private var aftermathActions: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
            Text("Next steps")
                .font(.headline)
            Button {
                shareFollowUpDraft()
            } label: {
                Label("Draft follow-up message", systemImage: "envelope")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(DesignTokens.accent)

            if !sortedActions.filter({ $0.status == .open }).isEmpty || !conversation.keyPoints.isEmpty {
                Button {
                    Task { await addExtractedTodos() }
                } label: {
                    Label("Add open actions to To-dos", systemImage: "checklist")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(DesignTokens.accent)
            }
        }
        .padding(.top, DesignTokens.spaceS)
    }

    private func shareFollowUpDraft() {
        var lines: [String] = ["Hi —", ""]
        if let summary = conversation.summaryText, !summary.isEmpty {
            lines += ["Quick recap:", summary, ""]
        }
        if !conversation.keyPoints.isEmpty {
            lines += ["Key points:"] + conversation.keyPoints.map { "• \($0)" } + [""]
        }
        let open = sortedActions.filter { $0.status == .open }.map(\.text)
        if !open.isEmpty {
            lines += ["Action items:"] + open.map { "• \($0)" } + [""]
        }
        lines += ["Thanks,", ""]
        let text = lines.joined(separator: "\n")
        UIPasteboard.general.string = text
        shareLinkURL = nil
        withAnimation { quoteSavedMessage = "Follow-up draft copied" }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation { quoteSavedMessage = nil }
        }
        // Also present system share sheet with the draft text.
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("afterna-followup.txt")
        try? text.data(using: .utf8)?.write(to: url)
        shareLinkURL = url
    }

    private func addExtractedTodos() async {
        let existing = Set(sortedActions.map { $0.text.lowercased() })
        var added = 0
        let candidates: [String]
        let openActions = sortedActions.filter { $0.status == .open }.map(\.text)
        if !openActions.isEmpty {
            // Open extract actions already live on this memory's To-dos tab — mirror any missing ones.
            candidates = openActions
        } else {
            candidates = Array(conversation.keyPoints.prefix(8))
        }
        for text in candidates {
            guard !existing.contains(text.lowercased()) else { continue }
            await container.memoryOrg.createTodo(
                text: text,
                conversation: conversation,
                modelContext: modelContext
            )
            added += 1
        }
        withAnimation {
            quoteSavedMessage = added > 0 ? "Added \(added) to-do(s)" : "To-dos already up to date"
        }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        withAnimation { quoteSavedMessage = nil }
    }

    private var draftArchiveCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
            infoCard(
                symbol: "tray.and.arrow.down",
                text: "This draft is saved on your device. Archive it to generate a summary and key points."
            )
            Button {
                Task { await archiveDraft() }
            } label: {
                Text(isArchivingDraft ? "Archiving…" : "Archive & extract key points")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.accent)
            .disabled(isArchivingDraft || conversation.segments.isEmpty)
            .accessibilityLabel("Archive draft and extract key points")

            if let archiveDraftError {
                Text(archiveDraftError)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.error)
            }
        }
    }

    @MainActor
    private func archiveDraft() async {
        isArchivingDraft = true
        archiveDraftError = nil
        defer { isArchivingDraft = false }
        do {
            try await container.memoryOrg.archiveDraft(
                conversation,
                api: container.api,
                modelContext: modelContext,
                usesMockUpload: container.usesMockUpload
            )
            Haptics.success()
            await hydrate()
        } catch {
            archiveDraftError = error.localizedDescription
        }
    }

    @ViewBuilder
    private var summaryContent: some View {
        if let summary = conversation.summaryText, !summary.isEmpty {
            Text(summary)
                .font(DesignTokens.bodyFont)
                .foregroundStyle(DesignTokens.ink)
        } else if conversation.statusRaw == "draft" {
            EmptyView()
        } else if conversation.serverConversationId == nil {
            infoCard(
                symbol: "iphone",
                text: "This memory lives only on this device, so there is no AI summary. Archived recordings get summaries and key points automatically."
            )
        } else if conversation.statusRaw == "failed" {
            VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
                infoCard(
                    symbol: "exclamationmark.triangle",
                    text: "Something went wrong while generating the summary.",
                    tint: DesignTokens.error
                )
                Button {
                    Task { await hydrate() }
                } label: {
                    Label("Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .tint(DesignTokens.accent)
            }
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
                HStack(spacing: DesignTokens.spaceS) {
                    ProgressView()
                    Text("Key points are generating…")
                        .font(DesignTokens.bodyFont)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                Button {
                    Task { await hydrate() }
                } label: {
                    Label(isHydrating ? "Checking…" : "Check again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .tint(DesignTokens.accent)
                .disabled(isHydrating)
            }
        }
    }

    private func bulletSection(title: String, items: [String], symbol: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.self) { point in
                HStack(alignment: .top, spacing: DesignTokens.spaceS) {
                    Image(systemName: symbol)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.accent)
                        .padding(.top, 4)
                    Text(point)
                        .font(DesignTokens.bodyFont)
                }
            }
        }
        .padding(.top, DesignTokens.spaceXS)
    }

    private func infoCard(symbol: String, text: String, tint: Color = DesignTokens.accent) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spaceS) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(text)
                .font(.callout)
                .foregroundStyle(DesignTokens.textSecondary)
        }
        .padding(DesignTokens.spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.mist.opacity(0.5), in: RoundedRectangle(cornerRadius: DesignTokens.radius))
    }

    // MARK: Transcript

    @ViewBuilder
    private var transcriptTab: some View {
        if sortedSegments.isEmpty {
            VStack {
                if conversation.serverConversationId != nil && conversation.statusRaw != "failed" {
                    ContentUnavailableView {
                        Label("Transcript on its way", systemImage: "waveform")
                    } description: {
                        Text("The transcript is still processing. Pull the Summary tab to refresh, or check back in a moment.")
                    }
                } else {
                    ContentUnavailableView(
                        "No transcript",
                        systemImage: "waveform.slash",
                        description: Text("This memory has no transcript yet. Record with live captions or import an audio file to get one.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(sortedSegments) { seg in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speaker \(seg.speakerLabel) · \(format(seg.startMs))")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.accent)
                    Text(seg.text)
                }
                .contextMenu {
                    Button {
                        Task {
                            await container.memoryOrg.saveQuote(
                                from: seg,
                                conversation: conversation,
                                modelContext: modelContext
                            )
                            withAnimation {
                                quoteSavedMessage = "Quote saved"
                            }
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            withAnimation { quoteSavedMessage = nil }
                        }
                    } label: {
                        Label("Save as pull quote", systemImage: "quote.bubble")
                    }
                    Button {
                        renameSpeakerFrom = seg.speakerLabel
                        renameSpeakerTo = seg.speakerLabel
                    } label: {
                        Label("Rename speaker…", systemImage: "person.crop.circle.badge.questionmark")
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: To-dos

    private var actionsTab: some View {
        List {
            Section {
                HStack {
                    TextField("New to-do", text: $newTodo)
                    Button("Add") {
                        Task {
                            await container.memoryOrg.createTodo(
                                text: newTodo,
                                conversation: conversation,
                                modelContext: modelContext
                            )
                            newTodo = ""
                        }
                    }
                    .disabled(newTodo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            Section("Open") {
                ForEach(sortedActions.filter { $0.status == .open }) { item in
                    todoRow(item)
                }
            }
            Section("Done") {
                ForEach(sortedActions.filter { $0.status == .done }) { item in
                    todoRow(item)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: Quotes

    private var quotesTab: some View {
        Group {
            if sortedQuotes.isEmpty {
                ContentUnavailableView(
                    "No pull quotes",
                    systemImage: "quote.bubble",
                    description: Text("Long-press a transcript line and choose Save as pull quote.")
                )
            } else {
                List {
                    ForEach(sortedQuotes) { quote in
                        quoteCard(quote)
                            .swipeActions {
                                Button(role: .destructive) {
                                    quoteToDelete = quote
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func todoRow(_ item: ActionItemEntity) -> some View {
        HStack(alignment: .top) {
            Button {
                Task {
                    let next: ActionItemStatus = item.status == .open ? .done : .open
                    await container.memoryOrg.setTodoStatus(item, status: next, modelContext: modelContext)
                }
            } label: {
                Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(DesignTokens.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.status == .done ? "Mark as open" : "Mark as done")
            Text(item.text)
                .strikethrough(item.status == .done)
                .foregroundStyle(item.status == .done ? .secondary : DesignTokens.ink)
            Spacer()
        }
        .swipeActions {
            Button(role: .destructive) {
                todoToDelete = item
            } label: {
                Label("Delete", systemImage: "trash")
            }
            if item.status == .open {
                Button("Dismiss") {
                    Task { await container.memoryOrg.setTodoStatus(item, status: .dismissed, modelContext: modelContext) }
                }
            }
        }
    }

    private func quoteCard(_ quote: QuoteEntity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("“\(quote.text)”")
                .font(DesignTokens.bodyFont)
            HStack {
                if let speaker = quote.speakerLabel {
                    Text("Speaker \(speaker)")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.accent)
                }
                if let start = quote.startMs {
                    Text(format(start))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Export

    private var exportText: String {
        var lines: [String] = [conversation.title, ""]
        if let summary = conversation.summaryText, !summary.isEmpty {
            lines += ["Summary", summary, ""]
        }
        if !conversation.keyPoints.isEmpty {
            lines += ["Key points"] + conversation.keyPoints.map { "• \($0)" } + [""]
        }
        if !conversation.decisions.isEmpty {
            lines += ["Decisions"] + conversation.decisions.map { "• \($0)" } + [""]
        }
        if !sortedSegments.isEmpty {
            lines.append("Transcript")
            for seg in sortedSegments {
                lines.append("[\(format(seg.startMs))] Speaker \(seg.speakerLabel): \(seg.text)")
            }
        }
        lines += ["", "— Shared from Afterna"]
        return lines.joined(separator: "\n")
    }

    private func format(_ ms: Int) -> String {
        let s = ms / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

enum DetailTab: CaseIterable {
    case summary, transcript, actions, quotes
    var title: String {
        switch self {
        case .summary: return "Summary"
        case .transcript: return "Transcript"
        case .actions: return "To-dos"
        case .quotes: return "Quotes"
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
