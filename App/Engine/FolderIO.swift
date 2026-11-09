import Foundation

/// File work, off the main thread. Reads and writes are coordinated so iCloud Drive sees them,
/// and coordinated reads download files that are only in the cloud.
enum FolderIO {
    struct Incoming {
        var states: [ProgressState] = []
        var units: [Unit] = []
        var words: [Word] = []
        var downloading = 0
    }

    static func read(_ folder: URL, skipping device: String) throws -> Incoming {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        var result = Incoming()
        let decoder = JSONDecoder()
        for url in try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: []) {
            var name = url.lastPathComponent
            // Files not yet downloaded show up as ".name.icloud" placeholders.
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                name = String(name.dropFirst().dropLast(7))
                try? fm.startDownloadingUbiquitousItem(at: folder.appendingPathComponent(name))
                if isPeerFile(name, device) { result.downloading += 1 }
                continue
            }
            guard isPeerFile(name, device), let data = coordinatedRead(url) else { continue }
            if name.hasPrefix("progress-") {
                if let s = try? decoder.decode(ProgressState.self, from: data) { result.states.append(s) }
            } else if let lex = try? decoder.decode(LexiconFile.self, from: data) {
                result.units += lex.units
                result.words += lex.words
            }
        }
        return result
    }

    static func write(_ folder: URL, device: String, state: ProgressState, lexicon: LexiconFile) throws {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try coordinatedWrite(encoder.encode(state), to: folder.appendingPathComponent("progress-\(device).json"))
        try coordinatedWrite(encoder.encode(lexicon), to: folder.appendingPathComponent("words-\(device).json"))
    }

    private static func isPeerFile(_ name: String, _ device: String) -> Bool {
        (name.hasPrefix("progress-") || name.hasPrefix("words-")) && name.hasSuffix(".json") && !name.contains(device)
    }

    private static func coordinatedRead(_ url: URL) -> Data? {
        var data: Data?
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { data = try? Data(contentsOf: $0) }
        return data
    }

    private static func coordinatedWrite(_ data: Data, to url: URL) throws {
        // Skip unchanged files so iCloud Drive isn't kept busy re-uploading.
        if let existing = coordinatedRead(url), existing == data { return }
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { target in
            do { try data.write(to: target, options: .atomic) } catch { writeError = error }
        }
        if let e = coordError ?? writeError { throw e }
    }
}
