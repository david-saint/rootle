import Foundation
import Observation

enum ExerciseKind: Equatable {
    case intro, meaning, literal, wordFromLiteral, origin, rootMeaning, build, journey, factOrFib, match

    var label: String {
        switch self {
        case .intro: "New word"
        case .meaning: "Meaning"
        case .literal: "Dig deeper"
        case .wordFromLiteral: "Name that word"
        case .origin: "Where from?"
        case .rootMeaning: "Root"
        case .build: "Build it"
        case .journey: "Time travel"
        case .factOrFib: "Fact or fib?"
        case .match: "Match up"
        }
    }

    var symbol: String {
        switch self {
        case .intro: "sparkle"
        case .meaning: "text.quote"
        case .literal: "arrow.down.to.line"
        case .wordFromLiteral: "questionmark.bubble"
        case .origin: "globe.europe.africa"
        case .rootMeaning: "leaf"
        case .build: "square.stack.3d.up"
        case .journey: "clock.arrow.circlepath"
        case .factOrFib: "checkmark.seal"
        case .match: "link"
        }
    }

    var isChoice: Bool { [.meaning, .literal, .wordFromLiteral, .origin, .rootMeaning, .factOrFib].contains(self) }
}

struct Tile: Identifiable, Hashable {
    let id: Int
    let text: String
    var detail: String? = nil
}

struct Exercise: Identifiable {
    var id = UUID()
    let kind: ExerciseKind
    let word: Word?
    var prompt: String = ""
    var options: [String] = []
    var answer: String = ""
    var tiles: [Tile] = []
    var solution: [Int] = []
    var pairs: [(left: String, right: String)] = []
    var explanation: String? = nil
    var isRetry = false
}

struct LessonRequest: Identifiable {
    let id = UUID()
    let title: String
    let exercises: [Exercise]
    let nodeID: String?
    let newWordIDs: [String]
}

@Observable
final class LessonSession {
    private(set) var queue: [Exercise]
    private(set) var index = 0
    private(set) var combo = 0
    private(set) var bestCombo = 0
    private(set) var answered = 0
    private(set) var firstTryCorrect = 0
    private(set) var mistakes = 0
    private(set) var retries = 0
    private(set) var xp = 0

    init(exercises: [Exercise]) { queue = exercises }

    var current: Exercise { queue[min(index, queue.count - 1)] }
    var isDone: Bool { index >= queue.count }
    var progress: Double { queue.isEmpty ? 1 : Double(index) / Double(queue.count) }

    func record(correct: Bool) {
        let ex = current
        guard ex.kind != .intro else { return }
        answered += 1
        if ex.isRetry { retries += 1 }
        if correct {
            if !ex.isRetry { firstTryCorrect += 1 }
            combo += 1
            bestCombo = max(bestCombo, combo)
            xp += 2 + (combo % 5 == 0 ? 5 : 0)
        } else {
            mistakes += 1
            combo = 0
            if !ex.isRetry {
                var again = ex
                again.id = UUID()
                again.isRetry = true
                queue.append(again)
            }
        }
    }

    func advance() { index += 1 }
}

/// Builds lessons out of the lexicon. Every question doubles as a little etymology lesson.
enum LessonBuilder {
    static var lex: Lexicon { Lexicon.shared }

    static func lesson(for node: PathNode, replay: Bool) -> LessonRequest {
        let words = node.wordIDs.compactMap { lex.word($0) }
        let unit = lex.units[node.unitIndex]
        switch node.kind {
        case .lesson(let i):
            return LessonRequest(title: "\(unit.title) · \(i + 1)",
                                 exercises: replay ? review(words, count: 8) : learn(words),
                                 nodeID: node.id, newWordIDs: node.wordIDs)
        case .review:
            return LessonRequest(title: "\(unit.title) · Treasure",
                                 exercises: review(words, count: 9),
                                 nodeID: node.id, newWordIDs: node.wordIDs)
        }
    }

    static func practice(_ words: [Word]) -> LessonRequest {
        LessonRequest(title: "Refresh your roots", exercises: review(words, count: 8), nodeID: nil, newWordIDs: [])
    }

    /// New words: introduce each, quiz it straight away, match them up, then mix it up.
    static func learn(_ words: [Word]) -> [Exercise] {
        var out: [Exercise] = []
        for (i, w) in words.enumerated() {
            out.append(Exercise(kind: .intro, word: w))
            out.append(i.isMultiple(of: 2) ? literal(w) : meaning(w))
        }
        if words.count >= 3 { out.append(match(words)) }
        var used: [ExerciseKind] = []
        for w in words.shuffled() {
            if let ex = varied(w, avoiding: used) { out.append(ex); used.append(ex.kind) }
        }
        return out
    }

    static func review(_ words: [Word], count: Int) -> [Exercise] {
        var out: [Exercise] = []
        let pool = words.shuffled()
        if pool.count >= 4 { out.append(match(Array(pool.prefix(4)))) }
        var used: [ExerciseKind] = []
        var i = 0
        while out.count < count && !pool.isEmpty && i < count * 3 {
            let w = pool[i % pool.count]
            if let ex = varied(w, avoiding: Array(used.suffix(2))) { out.append(ex); used.append(ex.kind) }
            i += 1
        }
        if pool.count >= 8 { out.insert(match(Array(pool.suffix(4))), at: min(out.count, count / 2 + 1)) }
        return out
    }

    static func varied(_ w: Word, avoiding: [ExerciseKind]) -> Exercise? {
        var makers: [(ExerciseKind, () -> Exercise?)] = [
            (.origin, { origin(w) }),
            (.wordFromLiteral, { wordFromLiteral(w) }),
            (.factOrFib, { factOrFib(w) }),
            (.meaning, { meaning(w) }),
            (.literal, { literal(w) }),
        ]
        if w.parts.count >= 1 { makers.append((.rootMeaning, { rootMeaning(w) })) }
        if w.parts.count >= 2 { makers.append((.build, { build(w) })); makers.append((.build, { build(w) })) }
        if w.journey.count >= 3 { makers.append((.journey, { journey(w) })); makers.append((.journey, { journey(w) })) }
        if w.myth != nil { makers.append((.factOrFib, { myth(w) })); makers.append((.factOrFib, { myth(w) })) }
        let fresh = makers.filter { !avoiding.contains($0.0) }
        return (fresh.randomElement() ?? makers.randomElement())?.1()
    }

    // MARK: Exercise makers

    private static func others(_ w: Word, _ n: Int) -> [Word] {
        Array(lex.ordered.filter { $0.id != w.id }.shuffled().prefix(n))
    }

    static func meaning(_ w: Word) -> Exercise {
        let opts = ([w.def] + others(w, 3).map(\.def)).shuffled()
        return Exercise(kind: .meaning, word: w, prompt: "What does **\(w.word)** mean?", options: opts, answer: w.def)
    }

    static func literal(_ w: Word) -> Exercise {
        let opts = ([w.lit] + others(w, 3).map(\.lit)).shuffled()
        return Exercise(kind: .literal, word: w, prompt: "Dig to the bottom: what did **\(w.word)** first mean?", options: opts, answer: w.lit)
    }

    static func wordFromLiteral(_ w: Word) -> Exercise {
        let opts = ([w.word] + others(w, 3).map(\.word)).shuffled()
        return Exercise(kind: .wordFromLiteral, word: w, prompt: "Which word began as *“\(w.lit)”*?", options: opts, answer: w.word)
    }

    static func origin(_ w: Word) -> Exercise {
        let opts = ([w.origin] + lex.origins.filter { $0 != w.origin }.shuffled().prefix(3)).shuffled()
        return Exercise(kind: .origin, word: w, prompt: "Where are the deepest roots of **\(w.word)**?", options: opts, answer: w.origin)
    }

    static func rootMeaning(_ w: Word) -> Exercise {
        let part = w.parts.randomElement()!
        let decoys = lex.ordered.flatMap(\.parts).map(\.m).filter { $0 != part.m }
        let opts = ([part.m] + Array(Set(decoys)).shuffled().prefix(3)).shuffled()
        return Exercise(kind: .rootMeaning, word: w, prompt: "In **\(w.word)**, what does the piece **\(part.p)** mean?", options: opts, answer: part.m)
    }

    static func build(_ w: Word) -> Exercise {
        let decoys = Array(Set(lex.ordered.filter { $0.id != w.id }.flatMap(\.parts).map(\.p)).subtracting(w.parts.map(\.p))).shuffled().prefix(2)
        var tiles = w.parts.enumerated().map { Tile(id: $0.offset, text: $0.element.p, detail: $0.element.m) }
        tiles += decoys.enumerated().map { Tile(id: 100 + $0.offset, text: $0.element) }
        return Exercise(kind: .build, word: w,
                        prompt: "Build the word that literally means *“\(w.lit)”*",
                        tiles: tiles.shuffled(), solution: Array(0..<w.parts.count))
    }

    static func journey(_ w: Word) -> Exercise {
        let steps = Array(w.journey.prefix(4))
        let tiles = steps.enumerated().map { Tile(id: $0.offset, text: $0.element.form, detail: $0.element.lang) }
        var shuffled = tiles.shuffled()
        while shuffled.map(\.id) == tiles.map(\.id) && tiles.count > 1 { shuffled.shuffle() }
        return Exercise(kind: .journey, word: w,
                        prompt: "Trace **\(w.word)** back in time — oldest first",
                        tiles: shuffled, solution: tiles.map(\.id))
    }

    static func factOrFib(_ w: Word) -> Exercise {
        if Bool.random() {
            return Exercise(kind: .factOrFib, word: w,
                            prompt: "**\(w.word)** comes from words meaning *“\(w.lit)”*.",
                            options: ["Fact", "Fib"], answer: "Fact")
        }
        let decoy = others(w, 1).first!
        return Exercise(kind: .factOrFib, word: w,
                        prompt: "**\(w.word)** comes from words meaning *“\(decoy.lit)”*.",
                        options: ["Fact", "Fib"], answer: "Fib",
                        explanation: "That's **\(decoy.word)**. **\(w.word)** was *“\(w.lit)”*.")
    }

    static func myth(_ w: Word) -> Exercise {
        Exercise(kind: .factOrFib, word: w, prompt: w.myth!.claim, options: ["Fact", "Fib"], answer: "Fib",
                 explanation: w.myth!.truth)
    }

    static func match(_ words: [Word]) -> Exercise {
        Exercise(kind: .match, word: nil, prompt: "Match each word to where it started",
                 pairs: words.map { ($0.word, $0.lit) })
    }
}
