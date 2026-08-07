import SwiftUI
import SwiftData

struct ConversationDetailView: View {
    @Bindable var conversation: ConversationEntity
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var tab: DetailTab = .summary
    @State private var newTodo = ""
    @State private var quoteSavedMessage: String?

    private var sortedQuotes: [QuoteEntity] {
        conversation.quotes.sorted { $0.createdAt > $1.createdAt }
    }

    private var sortedActions: [ActionItemEntity] {
        conversation.actionItems.sorted { $0.createdAt > $1.createdAt }
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await container.memoryOrg.togglePin(conversation, modelContext: modelContext) }
                } label: {
                    Image(systemName: conversation.isPinned ? "pin.fill" : "pin")
                }
            }
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

    private var summaryTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(conversation.title)
                    .font(DesignTokens.titleFont)
                Text("Status: \(conversation.statusRaw)")
                    .foregroundStyle(.secondary)
                Text("Summary will appear after auto-transcription + extract.")
                    .font(DesignTokens.bodyFont)

                if !sortedQuotes.isEmpty {
                    Text("Pull quotes")
                        .font(.headline)
                        .padding(.top, 8)
                    ForEach(sortedQuotes.prefix(5)) { quote in
                        quoteCard(quote)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private var transcriptTab: some View {
        List(conversation.segments) { seg in
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
    }

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
    }

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
                                Button("Delete", role: .destructive) {
                                    Task {
                                        await container.memoryOrg.deleteQuote(quote, modelContext: modelContext)
                                    }
                                }
                            }
                    }
                }
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
            Text(item.text)
                .strikethrough(item.status == .done)
                .foregroundStyle(item.status == .done ? .secondary : DesignTokens.ink)
            Spacer()
        }
        .swipeActions {
            Button("Delete", role: .destructive) {
                Task { await container.memoryOrg.deleteTodo(item, modelContext: modelContext) }
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
