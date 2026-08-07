import SwiftUI

struct ConversationDetailView: View {
    let conversation: ConversationEntity
    @State private var tab: DetailTab = .summary

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
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(conversation.title)
                            .font(DesignTokens.titleFont)
                        Text("Status: \(conversation.statusRaw)")
                            .foregroundStyle(.secondary)
                        Text("Summary will appear after auto-transcription + extract.")
                            .font(DesignTokens.bodyFont)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            case .transcript:
                List(conversation.segments) { seg in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speaker \(seg.speakerLabel) · \(format(seg.startMs))")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.accent)
                        Text(seg.text)
                    }
                }
            case .actions:
                ContentUnavailableView("Action items", systemImage: "checklist", description: Text("Extracted after transcription completes."))
            }
        }
        .background(DesignTokens.paper)
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func format(_ ms: Int) -> String {
        let s = ms / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

enum DetailTab: CaseIterable {
    case summary, transcript, actions
    var title: String {
        switch self {
        case .summary: return "Summary"
        case .transcript: return "Transcript"
        case .actions: return "Actions"
        }
    }
}
