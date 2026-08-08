import SwiftUI

struct PeopleView: View {
    @Environment(AppContainer.self) private var container
    @State private var people: [PersonSummary] = []
    @State private var busy = false
    @State private var errorText: String?
    @State private var askPerson: String?

    var body: some View {
        Group {
            if busy && people.isEmpty {
                ProgressView("Loading people…")
            } else if people.isEmpty {
                ContentUnavailableView(
                    "No people yet",
                    systemImage: "person.2",
                    description: Text("After you archive conversations, Afterna extracts people you talked about.")
                )
            } else {
                List(people) { person in
                    NavigationLink {
                        PersonDetailView(person: person)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.name)
                                    .font(DesignTokens.titleFont)
                                Text("\(person.mentionCount) mention\(person.mentionCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                askPerson = person.name
                            } label: {
                                Image(systemName: "sparkles")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Ask about \(person.name)")
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(DesignTokens.mist.opacity(0.35))
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(DesignTokens.paper)
        .navigationTitle("People")
        .task { await refresh() }
        .refreshable { await refresh() }
        .sheet(item: Binding(
            get: { askPerson.map { PersonAskTarget(name: $0) } },
            set: { askPerson = $0?.name }
        )) { target in
            AskAISheet(personName: target.name)
        }
        .overlay {
            if let errorText {
                Text(errorText).foregroundStyle(DesignTokens.error)
            }
        }
    }

    private func refresh() async {
        busy = true
        defer { busy = false }
        do {
            people = try await container.api.listPeople().people
            errorText = nil
        } catch {
            errorText = "Couldn’t load people."
        }
    }
}

private struct PersonAskTarget: Identifiable {
    var id: String { name }
    let name: String
}

struct PersonDetailView: View {
    let person: PersonSummary
    @Environment(AppContainer.self) private var container
    @State private var detail: PersonDetailResponse?
    @State private var showAsk = false

    var body: some View {
        List {
            Section {
                Text(person.name)
                    .font(DesignTokens.titleFont)
                Button {
                    showAsk = true
                } label: {
                    Label("Ask about \(person.name)", systemImage: "sparkles")
                }
            }
            if let detail {
                if !detail.openTodos.isEmpty {
                    Section("Open to-dos") {
                        ForEach(detail.openTodos, id: \.self) { todo in
                            Text(todo)
                        }
                    }
                }
                Section("Related memories") {
                    Text("\(detail.relatedConversationIds.count) conversation(s)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DesignTokens.paper)
        .navigationTitle(person.name)
        .task {
            detail = try? await container.api.personDetail(id: person.id)
        }
        .sheet(isPresented: $showAsk) {
            AskAISheet(personName: person.name)
        }
    }
}
