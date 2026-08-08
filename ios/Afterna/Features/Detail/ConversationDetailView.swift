import SwiftUI
import SwiftData

struct ConversationDetailView: View {
    @Bindable var conversation: ConversationEntity
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var tab: DetailTab = .summary
    @State private var newTodo = ""
    @State private var quoteSavedMessage: String?
    @State private var isHydrating = false

    @State private var showAsk = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var quoteToDelete: QuoteEntity?
    @State private var todoToDelete: ActionItemEntity?

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
                Button {
                    showAsk = true
                } label: {
                    Image(systemName: "sparkles")
                }
                .disabled(conversation.serverConversationId == nil)
                .accessibilityLabel("Ask AI about this memory")

                ShareLink(item: exportText, subject: Text(conversation.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share transcript and summary")

                Menu {
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

    private func hydrate() async {
        guard conversation.serverConversationId != nil else { return }
        isHydrating = true
        defer { isHydrating = false }
        await container.memoryOrg.hydrateFromServer(conversation, api: container.api, modelContext: modelContext)
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

                summaryContent

                if !conversation.keyPoints.isEmpty {
                    bulletSection(title: "Key points", items: conversation.keyPoints, symbol: "sparkle")
                }

                if !conversation.decisions.isEmpty {
                    bulletSection(title: "Decisions", items: conversation.decisions, symbol: "checkmark.seal")
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

    @ViewBuilder
    private var summaryContent: some View {
        if let summary = conversation.summaryText, !summary.isEmpty {
            Text(summary)
                .font(DesignTokens.bodyFont)
                .foregroundStyle(DesignTokens.ink)
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

// MARK: - Ask AI

struct AskAISheet: View {
    let conversation: ConversationEntity
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var question = ""
    @State private var answer: AskResponse?
    @State private var busy = false
    @State private var errorText: String?
    @FocusState private var questionFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spaceM) {
                    Text("Ask about this memory")
                        .font(DesignTokens.titleFont)
                        .foregroundStyle(DesignTokens.ink)

                    HStack(spacing: DesignTokens.spaceS) {
                        TextField("e.g. What did we decide?", text: $question, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .focused($questionFocused)
                            .onSubmit { Task { await ask() } }
                        Button {
                            Task { await ask() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                        }
                        .disabled(busy || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Ask")
                    }

                    if busy {
                        HStack(spacing: DesignTokens.spaceS) {
                            ProgressView()
                            Text("Thinking…")
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.error)
                    }

                    if let answer {
                        Text(answer.answer)
                            .font(DesignTokens.bodyFont)
                            .padding(DesignTokens.spaceM)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DesignTokens.mist.opacity(0.5), in: RoundedRectangle(cornerRadius: DesignTokens.radius))

                        if !answer.citations.isEmpty {
                            Text("From the conversation")
                                .font(.headline)
                            ForEach(answer.citations) { citation in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("“\(citation.quote)”")
                                        .font(.callout)
                                    HStack {
                                        if let speaker = citation.speakerLabel {
                                            Text("Speaker \(speaker)")
                                        }
                                        Text(formatMs(citation.tStartMs))
                                    }
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.accent)
                                }
                                .padding(DesignTokens.spaceS)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DesignTokens.paper, in: RoundedRectangle(cornerRadius: DesignTokens.radius))
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .background(DesignTokens.paper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { questionFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func ask() async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !busy else { return }
        busy = true
        errorText = nil
        defer { busy = false }
        do {
            answer = try await container.api.ask(
                question: trimmed,
                conversationId: conversation.serverConversationId,
                scope: "conversation"
            )
        } catch {
            errorText = "Couldn’t get an answer — check your connection and try again."
        }
    }

    private func formatMs(_ ms: Int) -> String {
        let s = ms / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
