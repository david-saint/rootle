import Foundation

struct JourneyStep: Codable, Hashable {
    let lang: String
    let form: String
    let gloss: String
    let date: String
}

struct WordPart: Codable, Hashable {
    let p: String
    let m: String
}

struct Myth: Codable, Hashable {
    let claim: String
    let truth: String
}

struct Word: Codable, Identifiable, Hashable {
    let id: String
    let word: String
    let pron: String
    let pos: String
    let def: String
    let lit: String
    let origin: String
    let journey: [JourneyStep]
    let parts: [WordPart]
    let story: String
    let example: String
    let related: [String]
    let myth: Myth?
}

struct Unit: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let emblem: String
    let words: [String]
    /// When a generated layer was dug, so every device stacks layers in the same order.
    var created: Date? = nil
}

/// One stop on the dig-site path: two lessons of four words, then a review "treasure" node.
struct PathNode: Identifiable, Hashable {
    enum Kind: Hashable { case lesson(Int), review }
    let id: String
    let unitIndex: Int
    let kind: Kind
    let wordIDs: [String]
}

struct LexiconFile: Codable {
    var units: [Unit] = []
    var words: [Word] = []
}

/// Words and layers Claude has dug up on this device, kept in the app group so the widget sees them too.
enum GeneratedLexicon {
    static var url: URL {
        let fm = FileManager.default
        if let id = SharedStore.groupID, let dir = fm.containerURL(forSecurityApplicationGroupIdentifier: id) {
            return dir.appendingPathComponent("generated-lexicon.json")
        }
        let dir = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        return dir.appendingPathComponent("generated-lexicon.json")
    }

    static func load() -> LexiconFile {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(LexiconFile.self, from: data) else { return LexiconFile() }
        return file
    }

    /// Called after new material is generated on this device (the app uses it to upload to iCloud).
    nonisolated(unsafe) static var onAppend: (([Unit], [Word]) -> Void)?

    /// Appends new material, skipping any word or layer id that already exists.
    static func append(units: [Unit] = [], words: [Word], notify: Bool = true) throws {
        var file = load()
        let known = Set(Lexicon.shared.words.keys).union(file.words.map(\.id))
        let fresh = words.filter { !known.contains($0.id) }
        file.words += fresh
        let knownUnits = Set(Lexicon.shared.units.map(\.id)).union(file.units.map(\.id))
        let freshUnits = units.filter { !knownUnits.contains($0.id) }
        guard !fresh.isEmpty || !freshUnits.isEmpty else { return }
        file.units += freshUnits
        let data = try JSONEncoder().encode(file)
        try data.write(to: url, options: .atomic)
        Lexicon.reload()
        if notify { onAppend?(freshUnits, fresh) }
    }
}

final class Lexicon {
    /// The current lexicon: bundled words plus everything generated so far. Call `reload()` after generating.
    private(set) static var shared = Lexicon()
    static func reload() { shared = Lexicon() }

    let units: [Unit]
    let words: [String: Word]
    /// Words in curriculum order: every layer's words, then loose words dug up one at a time.
    let ordered: [Word]
    let nodes: [PathNode]
    let origins: [String]
    /// Ids of every word that came from Claude rather than the bundled lexicon.
    let generatedIDs: Set<String>

    private init() {
        var units: [Unit] = []
        var words: [String: Word] = [:]
        let decoder = JSONDecoder()
        for name in ["lexicon-1", "lexicon-2"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { continue }
            do {
                let file = try decoder.decode(LexiconFile.self, from: data)
                units += file.units
                for w in file.words { words[w.id] = w }
            } catch {
                assertionFailure("Could not decode \(name): \(error)")
            }
        }
        let generated = GeneratedLexicon.load()
        var generatedIDs: Set<String> = []
        for w in generated.words where words[w.id] == nil {
            words[w.id] = w
            generatedIDs.insert(w.id)
        }
        let unitIDs = Set(units.map(\.id))
        units += generated.units
            .filter { !unitIDs.contains($0.id) && $0.words.allSatisfy { words[$0] != nil } }
            .sorted { ($0.created ?? .distantPast, $0.id) < ($1.created ?? .distantPast, $1.id) }

        self.units = units
        self.words = words
        self.generatedIDs = generatedIDs
        let inUnits = units.flatMap { $0.words.compactMap { words[$0] } }
        let placed = Set(inUnits.map(\.id))
        self.ordered = inUnits + generated.words.filter { !placed.contains($0.id) && words[$0.id] != nil }

        var nodes: [PathNode] = []
        for (i, unit) in units.enumerated() {
            let ids = unit.words
            let half = (ids.count + 1) / 2
            nodes.append(PathNode(id: "\(unit.id).1", unitIndex: i, kind: .lesson(0), wordIDs: Array(ids.prefix(half))))
            nodes.append(PathNode(id: "\(unit.id).2", unitIndex: i, kind: .lesson(1), wordIDs: Array(ids.dropFirst(half))))
            nodes.append(PathNode(id: "\(unit.id).review", unitIndex: i, kind: .review, wordIDs: ids))
        }
        self.nodes = nodes
        self.origins = Array(Set(words.values.map(\.origin))).sorted()
    }

    func word(_ id: String) -> Word? { words[id] }
    func nodes(forUnit index: Int) -> [PathNode] { nodes.filter { $0.unitIndex == index } }
}
