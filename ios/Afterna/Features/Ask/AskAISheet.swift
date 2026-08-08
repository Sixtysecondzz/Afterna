import SwiftUI
import SwiftData

/// Shared Ask AI sheet for a single memory or cross-conversation scope.
enum AskAIScope: String, CaseIterable, Identifiable, Hashable {
    case conversation
    case all
    case folder

    var id: String { rawValue }

    var label: String {
        switch self {
        case .conversation: return "This memory"
        case .all: return "All memories"
        case .folder: return "This folder"
        }
    }
}

struct AskAISheet: View {
    var conversation: ConversationEntity?

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Query private var conversations: [ConversationEntity]
    @Query private var folders: [FolderEntity]

    @State private var scope: AskAIScope
    @State private var crossConversationEnabled = false
    @State private var question = ""
    @State private var answer: AskResponse?
    @State private var busy = false
    @State private var errorText: String?
    @FocusState private var questionFocused: Bool

    init(conversation: ConversationEntity? = nil) {
        self.conversation = conversation
        _scope = State(initialValue: conversation == nil ? .all : .conversation)
    }

    private var availableScopes: [AskAIScope] {
        var scopes: [AskAIScope] = []
        if conversation != nil {
            scopes.append(.conversation)
        }
        if crossConversationEnabled {
            scopes.append(.all)
            if conversation?.folderId != nil {
                scopes.append(.folder)
            }
        }
        if scopes.isEmpty {
            scopes = conversation == nil ? [.all] : [.conversation]
        }
        return scopes
    }

    private var heading: String {
        switch scope {
        case .conversation: return "Ask about this memory"
        case .all: return "Ask across your memories"
        case .folder: return "Ask in this folder"
        }
    }

    private var citationsHeading: String {
        scope == .conversation ? "From the conversation" : "Sources"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spaceM) {
                    Text(heading)
                        .font(DesignTokens.titleFont)
                        .foregroundStyle(DesignTokens.ink)

                    if availableScopes.count > 1 {
                        Picker("Scope", selection: $scope) {
                            ForEach(availableScopes) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: scope) { _, _ in
                            answer = nil
                            errorText = nil
                        }
                    }

                    if scope == .folder, let folderName = folderName {
                        Text(folderName)
                            .font(DesignTokens.captionFont)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }

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
                                .foregroundStyle(DesignTokens.accent)
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
                            Text(citationsHeading)
                                .font(.headline)
                                .foregroundStyle(DesignTokens.ink)
                            ForEach(answer.citations) { citation in
                                citationRow(citation)
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
            .task {
                let config = container.flags.current()
                crossConversationEnabled = config.featureFlags.crossConversationSearch
                if !availableScopes.contains(scope) {
                    scope = availableScopes.first ?? (conversation == nil ? .all : .conversation)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var folderName: String? {
        guard let folderId = conversation?.folderId else { return nil }
        return folders.first(where: { $0.id == folderId || $0.serverId == folderId })?.name
    }

    @ViewBuilder
    private func citationRow(_ citation: Citation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if scope != .conversation, let title = memoryTitle(for: citation) {
                Text(title)
                    .font(DesignTokens.captionFont)
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)
            }
            Text("“\(citation.quote)”")
                .font(.callout)
                .foregroundStyle(DesignTokens.ink)
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
        .background(DesignTokens.mist.opacity(0.35), in: RoundedRectangle(cornerRadius: DesignTokens.radius))
    }

    private func memoryTitle(for citation: Citation) -> String? {
        guard let uuid = UUID(uuidString: citation.conversationId) else { return nil }
        return conversations.first { $0.serverConversationId == uuid }?.title
    }

    private func ask() async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !busy else { return }
        if scope == .conversation, conversation?.serverConversationId == nil {
            errorText = "This memory isn’t synced yet — try again after it finishes uploading."
            return
        }
        if scope == .folder, conversation?.folderId == nil {
            errorText = "This memory isn’t in a folder."
            return
        }

        busy = true
        errorText = nil
        defer { busy = false }
        do {
            answer = try await container.api.ask(
                question: trimmed,
                conversationId: scope == .conversation ? conversation?.serverConversationId : nil,
                scope: scope.rawValue,
                folderId: scope == .folder ? conversation?.folderId : nil
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
