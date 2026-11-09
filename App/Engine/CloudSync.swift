import Foundation
import Observation

/// Syncs progress and Claude-generated words between devices through a folder the player picks in
/// iCloud Drive (works without a paid developer account). Each device writes only its own two files —
/// `progress-<device>.json` and `words-<device>.json` — and reads everyone else's, so devices never
/// overwrite each other; `ProgressState.merged(with:)` folds them together.
@MainActor
@Observable
final class CloudSync {
    static let shared = CloudSync()

    enum Status: Equatable {
        case notSetUp, syncing, synced(Date), waiting(Int), failed(String)
    }
    private(set) var status: Status = .notSetUp
    private(set) var folderName: String?
    private(set) var inICloudDrive = true

    @ObservationIgnored private weak var store: GameStore?
    @ObservationIgnored private var folder: URL?
    @ObservationIgnored private var debounce: Task<Void, Never>?
    @ObservationIgnored private var heartbeat: Task<Void, Never>?
    @ObservationIgnored private var running = false

    private static let bookmarkKey = "rootle.syncFolderBookmark"

    private init() {}

    // MARK: Lifecycle

    func start(store: GameStore) {
        guard self.store == nil else { return }
        self.store = store
        folder = resolveBookmark()
        updateFolderInfo()
        GeneratedLexicon.onAppend = { [weak self] _, _ in
            Task { @MainActor in self?.progressChanged() }
        }
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                await self?.syncNow()
                try? await Task.sleep(for: .seconds(45))
            }
        }
    }

    /// Uses a folder the player just picked.
    func connect(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            #if os(macOS)
            let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            #else
            let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            #endif
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
            folder = url
            updateFolderInfo()
            Task { await syncNow() }
        } catch {
            status = .failed("Couldn't remember that folder: \(error.localizedDescription)")
        }
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        folder = nil
        updateFolderInfo()
    }

    /// Called after local changes; batches bursts into one write a few seconds later.
    func progressChanged() {
        guard folder != nil else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    // MARK: Sync

    func syncNow() async {
        guard let folder, let store, !running else {
            if folder == nil { status = .notSetUp }
            return
        }
        running = true
        defer { running = false }
        if case .synced = status {} else { status = .syncing }

        let device = DeviceID.current
        do {
            let incoming = try await Task.detached { try FolderIO.read(folder, skipping: device) }.value
            for remote in incoming.states { store.mergeRemote(remote) }
            if !incoming.units.isEmpty || !incoming.words.isEmpty {
                try GeneratedLexicon.append(units: incoming.units, words: incoming.words, notify: false)
                store.lexiconChanged()
            }
            let state = store.state
            let lexicon = GeneratedLexicon.load()
            try await Task.detached { try FolderIO.write(folder, device: device, state: state, lexicon: lexicon) }.value
            status = incoming.downloading > 0 ? .waiting(incoming.downloading) : .synced(.now)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: Folder bookmark

    private func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return nil }
        var stale = false
        #if os(macOS)
        let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
        #else
        let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        #endif
        if let url, stale { connect(url) }
        return url
    }

    private func updateFolderInfo() {
        folderName = folder?.lastPathComponent
        let path = folder?.path ?? ""
        inICloudDrive = folder == nil || path.contains("Mobile Documents") || path.contains("CloudDocs")
        if folder == nil { status = .notSetUp }
    }
}
