import SwiftUI
import SwiftData

/// Shared Ask AI sheet for a single memory, all memories, folder, or person.
enum AskAIScope: String, CaseIterable, Identifiable, Hashable {
    case conversation
    case all
    case folder
    case person

    var id: String { rawValue }

    var label: String {
        switch self {
        case .conversation: return "This memory"
        case .all: return "All memories"
        case .folder: return "This folder"
        case .person: return "Person"
        }
    }
}

struct AskAISheet: View {
    var conversation: ConversationEntity?
    var personName: String?

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

    init(conversation: ConversationEntity? = nil, personName: String? = nil) {
        self.conversation = conversation
        self.personName = personName
        if let personName, !personName.isEmpty {
            _scope = State(initialValue: .person)
        } else {
            _scope = State(initialValue: conversation == nil ? .all : .conversation)
        }
    }

    private var availableScopes: [AskAIScope] {
        var scopes: [AskAIScope] = []
        if conversation != nil { scopes.append(.conversation) }
        if let personName, !personName.isEmpty { scopes.append(.person) }
        if crossConversationEnabled {
            scopes.append(.all)
            if conversation?.folderId != nil { scopes.append(.folder) }
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
        case .person: return "Ask about \(personName ?? "this person")"
        }
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
                            Text("Searching your memories…")
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
                            Text(scope == .conversation ? "From the conversation" : "Sources")
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
        if let remote = citation.conversationTitle, !remote.isEmpty { return remote }
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
        if scope == .person, (personName ?? "").isEmpty {
            errorText = "No person selected."
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
                folderId: scope == .folder ? conversation?.folderId : nil,
                personName: scope == .person ? personName : nil
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
