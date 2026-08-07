import SwiftUI
import SwiftData

struct MemoriesView: View {
    @Query(sort: \ConversationEntity.createdAt, order: .reverse) private var conversations: [ConversationEntity]
    @Query(sort: \FolderEntity.name) private var folders: [FolderEntity]
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext

    @State private var selectedFolderId: UUID?
    @State private var showFolders = false
    @State private var assignTarget: ConversationEntity?

    private var filtered: [ConversationEntity] {
        let base: [ConversationEntity]
        if let selectedFolderId {
            base = conversations.filter {
                $0.folderId == selectedFolderId
                    || folders.first(where: { $0.id == selectedFolderId })?.serverId == $0.folderId
            }
        } else {
            base = conversations
        }
        return base.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
            return a.createdAt > b.createdAt
        }
    }

    /// Memories with native ads every `nativeFeedInterval` rows.
    private var feedItems: [MemoryFeedItem] {
        let interval = max(AdMobConfig.nativeFeedInterval, 2)
        var items: [MemoryFeedItem] = []
        var nativeSlot = 0
        for (index, conversation) in filtered.enumerated() {
            items.append(.memory(conversation))
            if (index + 1) % interval == 0 {
                items.append(.nativeAd(nativeSlot))
                nativeSlot += 1
            }
        }
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            folderChips
            ZStack {
                DesignTokens.paper.ignoresSafeArea()
                Group {
                    if filtered.isEmpty {
                        ContentUnavailableView(
                            "No memories yet",
                            systemImage: "waveform",
                            description: Text("Capture a conversation and Afterna will keep what was said.")
                        )
                    } else {
                        List {
                            ForEach(feedItems) { entry in
                                switch entry {
                                case .memory(let item):
                                    NavigationLink {
                                        ConversationDetailView(conversation: item)
                                            .onAppear {
                                                InterstitialAdManager.shared.showOnMemoryOpenIfNeeded()
                                            }
                                    } label: {
                                        memoryRow(item)
                                    }
                                    .listRowBackground(DesignTokens.mist.opacity(0.35))
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            Task { await container.memoryOrg.togglePin(item, modelContext: modelContext) }
                                        } label: {
                                            Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                                        }
                                        .tint(DesignTokens.accent)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            assignTarget = item
                                        } label: {
                                            Label("Folder", systemImage: "folder")
                                        }
                                    }
                                    .contextMenu {
                                        Button {
                                            Task { await container.memoryOrg.togglePin(item, modelContext: modelContext) }
                                        } label: {
                                            Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash.fill" : "pin.fill")
                                        }
                                        Button("Move to folder…") { assignTarget = item }
                                    }
                                case .nativeAd(let slot):
                                    NativeFeedAdView()
                                        .id("native-\(slot)")
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            BannerAdView()
                .background(DesignTokens.paper)
        }
        .navigationTitle("Memories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFolders = true
                } label: {
                    Image(systemName: "folder.badge.gearshape")
                }
            }
        }
        .sheet(isPresented: $showFolders) {
            FoldersManageSheet()
        }
        .sheet(item: $assignTarget) { conv in
            AssignFolderSheet(conversation: conv, folders: folders)
        }
        .task {
            SampleDataSeeder.seedIfNeeded(modelContext: modelContext)
            NativeAdManager.shared.preload()
            await container.memoryOrg.refreshAll(modelContext: modelContext)
        }
        .refreshable {
            await container.memoryOrg.refreshAll(modelContext: modelContext)
        }
    }

    private var folderChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", selected: selectedFolderId == nil) {
                    selectedFolderId = nil
                }
                ForEach(folders) { folder in
                    chip(title: folder.name, selected: selectedFolderId == folder.id) {
                        selectedFolderId = folder.id
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(DesignTokens.paper)
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(selected ? DesignTokens.accent.opacity(0.2) : DesignTokens.mist.opacity(0.5))
                )
                .foregroundStyle(DesignTokens.ink)
        }
        .buttonStyle(.plain)
    }

    private func memoryRow(_ item: ConversationEntity) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.accent)
                    .padding(.top, 4)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(DesignTokens.titleFont)
                    .foregroundStyle(DesignTokens.ink)
                Text("\(formatDuration(item.durationMs)) · \(item.statusRaw)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let folderId = item.folderId,
                   let name = folders.first(where: { $0.id == folderId || $0.serverId == folderId })?.name {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.accent)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ ms: Int) -> String {
        let s = max(ms / 1000, 0)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private enum MemoryFeedItem: Identifiable {
    case memory(ConversationEntity)
    case nativeAd(Int)

    var id: String {
        switch self {
        case .memory(let c): return "m-\(c.id.uuidString)"
        case .nativeAd(let slot): return "ad-\(slot)"
        }
    }
}

struct FoldersManageSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FolderEntity.name) private var folders: [FolderEntity]
    @State private var newName = ""
    @State private var renameTarget: FolderEntity?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                if container.memoryOrg.requiresSignIn || container.auth.userId == "demo" {
                    Text("Sign in to sync folders across devices. Local folders still work on this device after sync is available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Folders") {
                    ForEach(folders) { folder in
                        Text(folder.name)
                            .swipeActions {
                                Button("Rename") {
                                    renameTarget = folder
                                    renameText = folder.name
                                }
                                Button("Delete", role: .destructive) {
                                    Task { await container.memoryOrg.deleteFolder(folder, modelContext: modelContext) }
                                }
                            }
                    }
                }
                Section("New folder") {
                    HStack {
                        TextField("Name", text: $newName)
                        Button("Add") {
                            Task {
                                await container.memoryOrg.createFolder(name: newName, modelContext: modelContext)
                                newName = ""
                            }
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("Folders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename folder", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Save") {
                    if let folder = renameTarget {
                        Task { await container.memoryOrg.renameFolder(folder, name: renameText, modelContext: modelContext) }
                    }
                    renameTarget = nil
                }
                Button("Cancel", role: .cancel) { renameTarget = nil }
            }
        }
    }
}

struct AssignFolderSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let conversation: ConversationEntity
    let folders: [FolderEntity]

    var body: some View {
        NavigationStack {
            List {
                Button("No folder") {
                    Task {
                        await container.memoryOrg.assignFolder(conversation, folderId: nil, modelContext: modelContext)
                        dismiss()
                    }
                }
                ForEach(folders) { folder in
                    Button(folder.name) {
                        Task {
                            await container.memoryOrg.assignFolder(
                                conversation,
                                folderId: folder.serverId ?? folder.id,
                                modelContext: modelContext
                            )
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Move to folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
