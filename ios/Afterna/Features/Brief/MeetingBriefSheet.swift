import SwiftUI

struct MeetingBriefSheet: View {
    let meetingTitle: String
    let attendeeNames: [String]
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var brief: MeetingBriefResponse?
    @State private var busy = true
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spaceM) {
                    Text(meetingTitle)
                        .font(DesignTokens.titleFont)
                        .foregroundStyle(DesignTokens.ink)

                    if !attendeeNames.isEmpty {
                        Text(attendeeNames.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }

                    if busy {
                        HStack {
                            ProgressView()
                            Text("Preparing brief…")
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    } else if let errorText {
                        Text(errorText)
                            .foregroundStyle(DesignTokens.error)
                    } else if let brief {
                        if !brief.summarySnippets.isEmpty {
                            section(title: "Last time") {
                                ForEach(brief.summarySnippets, id: \.self) { snip in
                                    Text(snip)
                                        .font(DesignTokens.bodyFont)
                                }
                            }
                        }
                        if !brief.priorDecisions.isEmpty {
                            section(title: "Prior decisions") {
                                ForEach(brief.priorDecisions, id: \.self) { item in
                                    Label(item, systemImage: "checkmark.seal")
                                }
                            }
                        }
                        if !brief.openTodos.isEmpty {
                            section(title: "Open loops") {
                                ForEach(brief.openTodos, id: \.self) { item in
                                    Label(item, systemImage: "circle")
                                }
                            }
                        }
                        if !brief.suggestedQuestions.isEmpty {
                            section(title: "Ask them") {
                                ForEach(brief.suggestedQuestions, id: \.self) { q in
                                    Text("• \(q)")
                                        .font(DesignTokens.bodyFont)
                                }
                            }
                        }
                        if brief.summarySnippets.isEmpty && brief.priorDecisions.isEmpty && brief.openTodos.isEmpty {
                            Text("No prior Afterna memories for this meeting yet — capture this one and the next brief will be richer.")
                                .font(.callout)
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }
                }
                .padding()
            }
            .background(DesignTokens.paper)
            .navigationTitle("Meeting brief")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func load() async {
        busy = true
        defer { busy = false }
        do {
            brief = try await container.api.meetingBrief(title: meetingTitle, attendeeNames: attendeeNames)
        } catch {
            errorText = "Couldn’t load brief — check your connection."
        }
    }
}
