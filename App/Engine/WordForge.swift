import Foundation

/// Digs up new words with Claude: a whole new dig-site layer, or a handful of loose words.
/// Output is constrained to Rootle's word schema, so it drops straight into the lexicon.
enum WordForge {
    enum Failure: LocalizedError {
        case noKey, http(Int, String), refused, truncated, unreadable

        var errorDescription: String? {
            switch self {
            case .noKey: return "No Anthropic API key was built into this copy of Rootle. Run scripts/write_secrets.sh and rebuild."
            case .http(let code, let message): return "Claude couldn't dig right now (\(code)). \(message)"
            case .refused: return "Claude declined that request. Try again."
            case .truncated: return "The dig ran out of room before finishing. Try again."
            case .unreadable: return "The words came back garbled. Try again."
            }
        }
    }

    static let model = "claude-opus-5-5"

    static var apiKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "RootleAnthropicKey") as? String,
              !key.isEmpty, !key.hasPrefix("$(") else { return nil }
        return key
    }
    static var isAvailable: Bool { apiKey != nil }

    /// The layer emblems Claude can choose from, with what each picture shows.
    static let emblems: [(name: String, shows: String)] = [
        ("unit_shapeshifters", "a word changing shape — meanings that drifted"),
        ("unit_myth", "a classical temple and gods — mythology and legend"),
        ("unit_spice", "spice jars and a caravan — trade, food and the East"),
        ("unit_norse", "a Viking longship — Norse and Germanic roots"),
        ("unit_latin", "a Roman scroll and laurel — Latin roots"),
        ("unit_greek", "a Greek amphora — Greek roots"),
        ("unit_lost", "a broken word with a missing letter — words that lost or gained a letter"),
        ("unit_myths", "a magnifying glass over a fake label — busted folk etymologies"),
        ("unit_farshores", "a ship and a palm tree — words from far-off languages"),
        ("unit_longwords", "a very long ribbon of letters — long, fancy or rare words"),
    ]

    // MARK: Public

    /// A brand-new themed layer of eight words that the lexicon doesn't have yet.
    static func newLayer(lexicon: Lexicon) async throws -> (Unit, [Word]) {
        let taken = lexicon.units.map { "\($0.title) — \($0.subtitle)" }.joined(separator: "\n")
        let prompt = """
        Create the next layer of Rootle's dig site: a themed set of exactly 8 English words with fascinating, \
        well-documented etymologies.

        Pick a fresh theme that doesn't repeat these existing layers:
        \(taken)

        Good themes have a playful hook (for example: words from card games, animal names with hidden meanings, \
        words born from people's names, weather words, words from the sea, body-part metaphors). Mix everyday \
        words with one or two delightful rarer ones.

        Do not use any of these words, which the player already has:
        \(existingWords(lexicon))

        title: 1 to 3 catchy words, like "Shapeshifters" or "The Spice Road". subtitle: one short line saying \
        what links the words, like "Words that woke up meaning something else".

        Choose `emblem` from this list, picking the picture that best fits your theme:
        \(emblems.map { "- \($0.name): \($0.shows)" }.joined(separator: "\n"))
        """
        let raw: RawLayer = try await call(prompt: prompt, schema: layerSchema)
        let words = clean(raw.words, lexicon: lexicon)
        guard words.count >= 4 else { throw Failure.unreadable }
        let id = "gen-" + slug(raw.title)
        let emblem = emblems.contains { $0.name == raw.emblem } ? raw.emblem : "unit_shapeshifters"
        let unit = Unit(id: id, title: raw.title, subtitle: raw.subtitle, emblem: emblem, words: words.map(\.id), created: .now)
        return (unit, words)
    }

    /// A few standalone words for "dig up another word".
    static func looseWords(count: Int, lexicon: Lexicon) async throws -> [Word] {
        let prompt = """
        Dig up \(count) English words with surprising, well-documented etymologies — the kind that make someone \
        say "no way!". Vary them: different source languages, different parts of speech, a mix of everyday and \
        rarer words.

        Do not use any of these words, which the player already has:
        \(existingWords(lexicon))
        """
        let raw: RawWords = try await call(prompt: prompt, schema: wordsSchema)
        return clean(raw.words, lexicon: lexicon)
    }

    // MARK: Request

    private static let system = """
    You are the etymology editor of Rootle, a word-origins learning game. Every entry must be accurate: use \
    etymologies supported by the Oxford English Dictionary, Etymonline or Merriam-Webster. Never invent a \
    derivation. Where scholars disagree or the origin is uncertain, say so plainly in the story.

    Field guide for each word:
    - id: the word in lowercase, spaces replaced by hyphens.
    - pron: an easy respelling with the stressed syllable in capitals, e.g. "PAN-ik", "nyse".
    - def: the modern meaning, short.
    - lit: the literal original meaning, short and vivid, e.g. "not knowing", "of Pan".
    - origin: the language the word ultimately comes from, as a short name (e.g. "Latin", "Greek", \
      "Old Norse", "Old English", "Arabic", "Nahuatl").
    - journey: 3 to 5 steps from the oldest form to modern English, oldest first. date is short: "classical", \
      "1100s", "c. 1300", "1700s".
    - parts: the meaningful pieces of the oldest form (prefix, root, suffix) with what each meant. Use 2 or 3 \
      parts when the word divides; 1 when it doesn't.
    - story: 2 or 3 lively sentences telling how the meaning travelled. Plain words, no jargon.
    - example: one natural modern sentence using the word.
    - related: 2 to 4 English words that share a root.
    - myth: if there is a popular but false story about this word's origin, give it in claim (stated as if true) \
      and the correction in truth. If there is no well-known myth, leave both claim and truth as empty strings.
    """

    private static func call<T: Decodable>(prompt: String, schema: [String: Any]) async throws -> T {
        guard let key = apiKey else { throw Failure.noKey }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "fallbacks": "default",
            "output_config": [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": schema],
            ],
            "system": system,
            "messages": [["role": "user", "content": prompt]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let message = (try? JSONDecoder().decode(APIError.self, from: data))?.error.message ?? ""
            throw Failure.http(status, message)
        }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        if reply.stop_reason == "refusal" { throw Failure.refused }
        if reply.stop_reason == "max_tokens" { throw Failure.truncated }
        guard let text = reply.content.last(where: { $0.type == "text" })?.text,
              let json = text.data(using: .utf8) else { throw Failure.unreadable }
        do { return try JSONDecoder().decode(T.self, from: json) } catch { throw Failure.unreadable }
    }

    private struct Reply: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
        let stop_reason: String?
    }
    private struct APIError: Decodable {
        struct Body: Decodable { let message: String }
        let error: Body
    }

    // MARK: Shapes

    private struct RawMyth: Decodable { let claim: String; let truth: String }
    private struct RawWord: Decodable {
        let id, word, pron, pos, def, lit, origin, story, example: String
        let journey: [JourneyStep]
        let parts: [WordPart]
        let related: [String]
        let myth: RawMyth
    }
    private struct RawLayer: Decodable { let title: String; let subtitle: String; let emblem: String; let words: [RawWord] }
    private struct RawWords: Decodable { let words: [RawWord] }

    private static func clean(_ raw: [RawWord], lexicon: Lexicon) -> [Word] {
        var seen = Set(lexicon.words.keys)
        return raw.compactMap { r in
            let id = slug(r.word)
            guard !id.isEmpty, !seen.contains(id), r.journey.count >= 2, !r.parts.isEmpty else { return nil }
            seen.insert(id)
            let myth = r.myth.claim.trimmingCharacters(in: .whitespaces).isEmpty ? nil : Myth(claim: r.myth.claim, truth: r.myth.truth)
            return Word(id: id, word: r.word, pron: r.pron, pos: r.pos, def: r.def, lit: r.lit, origin: r.origin,
                        journey: r.journey, parts: r.parts, story: r.story, example: r.example,
                        related: r.related, myth: myth)
        }
    }

    private static func slug(_ s: String) -> String {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "en"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private static func existingWords(_ lexicon: Lexicon) -> String {
        lexicon.ordered.map(\.word).sorted().joined(separator: ", ")
    }

    private static func object(_ props: [String: Any]) -> [String: Any] {
        ["type": "object", "properties": props, "required": Array(props.keys).sorted(), "additionalProperties": false]
    }
    private static let str: [String: Any] = ["type": "string"]

    private static var wordSchema: [String: Any] {
        object([
            "id": str, "word": str, "pron": str, "pos": str, "def": str, "lit": str, "origin": str,
            "story": str, "example": str,
            "journey": ["type": "array", "items": object(["lang": str, "form": str, "gloss": str, "date": str])],
            "parts": ["type": "array", "items": object(["p": str, "m": str])],
            "related": ["type": "array", "items": str],
            "myth": object(["claim": str, "truth": str]),
        ])
    }
    private static var layerSchema: [String: Any] {
        object([
            "title": str, "subtitle": str,
            "emblem": ["type": "string", "enum": emblems.map(\.name)],
            "words": ["type": "array", "items": wordSchema],
        ])
    }
    private static var wordsSchema: [String: Any] {
        object(["words": ["type": "array", "items": wordSchema]])
    }
}
