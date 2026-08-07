import SwiftUI
import SwiftData

struct MemoriesView: View {
    @Query(sort: \ConversationEntity.createdAt, order: .reverse) private var conversations: [ConversationEntity]
    @Environment(AppContainer.self) private var container

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                DesignTokens.paper.ignoresSafeArea()
                Group {
                    if conversations.isEmpty {
                        ContentUnavailableView(
                            "No memories yet",
                            systemImage: "waveform",
                            description: Text("Capture a conversation and Afterna will keep what was said.")
                        )
                    } else {
                        List(conversations) { item in
                            NavigationLink {
                                ConversationDetailView(conversation: item)
                                    .onAppear {
                                        InterstitialAdManager.shared.showOnMemoryOpenIfNeeded()
                                    }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(DesignTokens.titleFont)
                                        .foregroundStyle(DesignTokens.ink)
                                    Text("\(formatDuration(item.durationMs)) · \(item.statusRaw)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(DesignTokens.mist.opacity(0.35))
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            BannerAdView()
                .background(DesignTokens.paper)
        }
        .navigationTitle("Memories")
    }

    private func formatDuration(_ ms: Int) -> String {
        let s = max(ms / 1000, 0)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
