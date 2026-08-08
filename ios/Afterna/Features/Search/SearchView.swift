import SwiftUI
import SwiftData

struct SearchView: View {
    @Query private var conversations: [ConversationEntity]
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                DesignTokens.paper.ignoresSafeArea()
                if query.isEmpty && conversations.isEmpty {
                    ContentUnavailableView(
                        "Nothing to search yet",
                        systemImage: "waveform",
                        description: Text("Capture or import a conversation first — then search everything that was said.")
                    )
                } else if query.isEmpty {
                    ContentUnavailableView(
                        "Search your memories",
                        systemImage: "magnifyingglass",
                        description: Text("Start typing to search titles and every transcript line.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List {
                        ForEach(filtered) { item in
                            NavigationLink {
                                ConversationDetailView(conversation: item)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title).font(DesignTokens.titleFont)
                                    if let hit = item.segments.first(where: { $0.text.localizedCaseInsensitiveContains(query) }) {
                                        Text(hit.text)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            BannerAdView()
                .background(DesignTokens.paper)
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Search memories")
    }

    private var filtered: [ConversationEntity] {
        guard !query.isEmpty else { return conversations }
        return conversations.filter { conv in
            conv.title.localizedCaseInsensitiveContains(query)
                || conv.segments.contains { $0.text.localizedCaseInsensitiveContains(query) }
        }
    }
}
