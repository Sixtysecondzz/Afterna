import SwiftUI
import SwiftData

struct TodosView: View {
    @Query(sort: \ActionItemEntity.createdAt, order: .reverse) private var items: [ActionItemEntity]
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var newTodo = ""
    @State private var showDone = false
    @State private var deleteTarget: ActionItemEntity?

    private var openItems: [ActionItemEntity] {
        items.filter { $0.status == .open }
    }

    private var doneItems: [ActionItemEntity] {
        items.filter { $0.status == .done }
    }

    var body: some View {
        List {
            if container.auth.userId == "demo" || container.memoryOrg.requiresSignIn {
                Section {
                    Text("Sign in to sync to-dos with Supabase. You can still add local to-dos on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    TextField("New to-do", text: $newTodo)
                    Button("Add") {
                        Task {
                            await container.memoryOrg.createTodo(
                                text: newTodo,
                                conversation: nil,
                                modelContext: modelContext
                            )
                            newTodo = ""
                        }
                    }
                    .disabled(newTodo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section("Open (\(openItems.count))") {
                if openItems.isEmpty {
                    Label("All clear — nothing open", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
                ForEach(openItems) { item in
                    todoRow(item)
                }
            }

            Section {
                Toggle("Show done", isOn: $showDone)
                if showDone {
                    ForEach(doneItems) { item in
                        todoRow(item)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DesignTokens.paper)
        .navigationTitle("To-dos")
        .confirmationDialog(
            "Delete this to-do?",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete to-do", role: .destructive) {
                if let item = deleteTarget {
                    Task { await container.memoryOrg.deleteTodo(item, modelContext: modelContext) }
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        }
        .task {
            await container.memoryOrg.refreshAll(modelContext: modelContext)
        }
        .refreshable {
            await container.memoryOrg.refreshAll(modelContext: modelContext)
        }
        .overlay {
            if container.memoryOrg.isSyncing {
                ProgressView()
            }
        }
    }

    private func todoRow(_ item: ActionItemEntity) -> some View {
        HStack(alignment: .top, spacing: 10) {
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

            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .strikethrough(item.status == .done)
                if let title = item.conversation?.title {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("General")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                deleteTarget = item
            } label: {
                Label("Delete", systemImage: "trash")
            }
            if item.status == .open {
                Button("Dismiss") {
                    Task {
                        await container.memoryOrg.setTodoStatus(item, status: .dismissed, modelContext: modelContext)
                    }
                }
            }
        }
    }
}
