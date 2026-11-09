import Foundation

/// Calendar-day helpers. Days are keyed as "yyyy-MM-dd" in the user's current calendar.
enum Day {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date = .now) -> String {
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func date(_ key: String) -> Date? {
        formatter.timeZone = .current
        return formatter.date(from: key)
    }

    static func adding(_ days: Int, to date: Date = .now) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func key(daysFromNow n: Int) -> String { key(adding(n)) }

    /// Whole days since 1 Jan 2026 — the seed for the word of the day.
    static func ordinal(_ date: Date = .now) -> Int {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        return cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: date)).day ?? 0
    }

    static func nextMidnight(after date: Date = .now) -> Date {
        Calendar.current.startOfDay(for: adding(1, to: date))
    }
}

/// Deterministic generator so every device shows the same word on the same day.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

extension Lexicon {
    /// The word of the day. Once a day's word is chosen it is pinned in `history`, so the lexicon can keep
    /// growing without reshuffling past days. Unpinned days draw deterministically from words that haven't
    /// been a word of the day yet, preferring ones the player hasn't learned.
    func wordOfTheDay(_ date: Date = .now, history: [String: String], learned: Set<String> = []) -> Word {
        let key = Day.key(date)
        if let id = history[key], let w = words[id] { return w }
        let used = Set(history.filter { $0.key != key }.values)
        let all = ordered.map(\.id)
        var pool = all.filter { !used.contains($0) && !learned.contains($0) }
        if pool.isEmpty { pool = all.filter { !used.contains($0) } }
        if pool.isEmpty { pool = all }
        pool.sort()
        var rng = SplitMix64(seed: 0x524F4F544C45 ^ UInt64(truncatingIfNeeded: Day.ordinal(date)))
        return words[pool[Int(rng.next() % UInt64(pool.count))]]!
    }

    /// Words that haven't been a word of the day or an extra find, and aren't learned yet.
    func unusedWords(state: ProgressState) -> [Word] {
        let used = Set(state.wotdByDay.values).union(state.extraWords.values.flatMap { $0 })
        return ordered.filter { !used.contains($0.id) && state.words[$0.id] == nil }
    }
}
