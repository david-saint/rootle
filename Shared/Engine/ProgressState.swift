import Foundation

/// Spaced-repetition memory for one word (Leitner boxes 0–5).
struct WordProgress: Codable, Hashable {
    var box: Int = 1
    var due: String
    var seen: Int = 0
    var correct: Int = 0
    var learnedOn: String

    static let intervals = [0, 1, 3, 7, 14, 30]
}

/// Additive totals earned on one device. Each device only ever writes its own tally, so merging
/// devices is just taking every device's latest tally (a grow-only counter per device).
struct Tally: Codable, Hashable {
    var xp = 0
    var lessonsDone = 0
    var perfectLessons = 0
    var dailyXP: [String: Int] = [:]

    /// The fuller of two copies of the same device's tally.
    static func newest(_ a: Tally, _ b: Tally) -> Tally {
        (a.xp, a.lessonsDone) >= (b.xp, b.lessonsDone) ? a : b
    }
}

/// Everything the player has done. Shared with the widget through the app group, and with the
/// player's other devices through iCloud. Every field merges without losing work (see `merged(with:)`).
struct ProgressState: Codable, Equatable {
    var words: [String: WordProgress] = [:]
    var completedNodes: Set<String> = []
    /// Days on which the player did something; the streak is derived from these.
    var activeDays: Set<String> = []
    var wotdCollected: Set<String> = []
    /// The word of the day chosen for each day, pinned once shown.
    var wotdByDay: [String: String] = [:]
    /// Extra words dug up on demand, by day.
    var extraWords: [String: [String]] = [:]
    /// Guess-the-origin answers before a new word is revealed: word id → guessed right.
    var guesses: [String: Bool] = [:]
    /// Per-device totals, keyed by device id.
    var tallies: [String: Tally] = [:]
    /// Best streak carried over from before streaks were derived from `activeDays`.
    var legacyLongestStreak = 0

    var dailyGoal = 20
    var reminderEnabled = false
    var reminderHour = 19
    var settingsUpdated = Date.distantPast
    /// Bumped by "Reset progress": anything from before it is discarded when devices merge.
    var resetAt = Date.distantPast

    init() {}

    // MARK: Totals

    var xp: Int { tallies.values.reduce(0) { $0 + $1.xp } }
    var lessonsDone: Int { tallies.values.reduce(0) { $0 + $1.lessonsDone } }
    var perfectLessons: Int { tallies.values.reduce(0) { $0 + $1.perfectLessons } }
    var dailyXP: [String: Int] {
        tallies.values.reduce(into: [:]) { acc, t in t.dailyXP.forEach { acc[$0.key, default: 0] += $0.value } }
    }

    mutating func addXP(_ n: Int, on day: String = Day.key()) {
        let id = DeviceID.current
        tallies[id, default: Tally()].xp += n
        tallies[id, default: Tally()].dailyXP[day, default: 0] += n
    }

    mutating func countLesson(perfect: Bool) {
        let id = DeviceID.current
        tallies[id, default: Tally()].lessonsDone += 1
        if perfect { tallies[id, default: Tally()].perfectLessons += 1 }
    }

    /// Marks today active. Returns true if that grew the streak.
    @discardableResult
    mutating func markActive(_ now: Date = .now) -> Bool {
        activeDays.insert(Day.key(now)).inserted
    }

    // MARK: Streaks

    /// The streak as it stands right now (it lapses after a missed day).
    func liveStreak(_ now: Date = .now) -> Int {
        var day = activeDays.contains(Day.key(now)) ? now : Day.adding(-1, to: now)
        var n = 0
        while activeDays.contains(Day.key(day)) {
            n += 1
            day = Day.adding(-1, to: day)
        }
        return n
    }

    var longestStreak: Int {
        var best = 0
        for key in activeDays {
            guard let d = Day.date(key), !activeDays.contains(Day.key(Day.adding(-1, to: d))) else { continue }
            var n = 1, cur = d
            while activeDays.contains(Day.key(Day.adding(1, to: cur))) { n += 1; cur = Day.adding(1, to: cur) }
            best = max(best, n)
        }
        return max(best, legacyLongestStreak)
    }

    func activeToday(_ now: Date = .now) -> Bool { activeDays.contains(Day.key(now)) }
    func xpToday(_ now: Date = .now) -> Int { dailyXP[Day.key(now)] ?? 0 }

    /// Today's word of the day for this player.
    func wordOfTheDay(_ date: Date = .now, in lexicon: Lexicon = .shared) -> Word {
        lexicon.wordOfTheDay(date, history: wotdByDay, learned: Set(words.keys))
    }

    /// 0 = dormant, 1…5 = growth stage of the streak plant.
    func growthStage(_ now: Date = .now) -> Int {
        switch liveStreak(now) {
        case 0: return 0
        case 1...2: return 1
        case 3...6: return 2
        case 7...13: return 3
        case 14...29: return 4
        default: return 5
        }
    }

    // MARK: Merging devices

    /// Combines two devices' progress. Nothing earned on either device is lost; a reset on either
    /// device wins over anything older than it.
    func merged(with other: ProgressState) -> ProgressState {
        if other.resetAt > resetAt { return other.merged(with: self) }
        var m = self
        if other.resetAt < resetAt {
            // The other copy predates our reset: keep only its settings if they're newer.
            if other.settingsUpdated > settingsUpdated { m.copySettings(from: other) }
            return m
        }
        for (id, theirs) in other.words {
            if let mine = m.words[id] {
                m.words[id] = (theirs.seen, theirs.box) > (mine.seen, mine.box) ? theirs : mine
            } else {
                m.words[id] = theirs
            }
        }
        m.completedNodes.formUnion(other.completedNodes)
        m.activeDays.formUnion(other.activeDays)
        m.wotdCollected.formUnion(other.wotdCollected)
        for (day, id) in other.wotdByDay {
            // Both devices may have pinned a word before syncing; settle on the same one everywhere.
            m.wotdByDay[day] = min(m.wotdByDay[day] ?? id, id)
        }
        for (day, ids) in other.extraWords {
            var list = m.extraWords[day] ?? []
            for id in ids where !list.contains(id) { list.append(id) }
            m.extraWords[day] = list
        }
        for (device, t) in other.tallies {
            m.tallies[device] = m.tallies[device].map { Tally.newest($0, t) } ?? t
        }
        for (id, right) in other.guesses { m.guesses[id] = (m.guesses[id] ?? false) || right }
        m.legacyLongestStreak = max(m.legacyLongestStreak, other.legacyLongestStreak)
        if other.settingsUpdated > settingsUpdated { m.copySettings(from: other) }
        return m
    }

    private mutating func copySettings(from o: ProgressState) {
        dailyGoal = o.dailyGoal
        reminderEnabled = o.reminderEnabled
        reminderHour = o.reminderHour
        settingsUpdated = o.settingsUpdated
    }

    // MARK: Coding

    private enum CodingKeys: String, CodingKey {
        case words, completedNodes, activeDays, wotdCollected, wotdByDay, extraWords, guesses, tallies, legacyLongestStreak
        case dailyGoal, reminderEnabled, reminderHour, settingsUpdated, resetAt
        // Fields from the first version, read once to migrate.
        case xp, dailyXP, lessonsDone, perfectLessons, streak, longestStreak, lastActive
    }

    // Tolerant decoding so new fields never wipe old progress.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v<T: Decodable>(_ k: CodingKeys, _ d: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? d }
        words = v(.words, [:])
        completedNodes = v(.completedNodes, [])
        activeDays = v(.activeDays, [])
        wotdCollected = v(.wotdCollected, [])
        wotdByDay = v(.wotdByDay, [:])
        extraWords = v(.extraWords, [:])
        guesses = v(.guesses, [:])
        tallies = v(.tallies, [:])
        legacyLongestStreak = v(.legacyLongestStreak, 0)
        dailyGoal = v(.dailyGoal, 20)
        reminderEnabled = v(.reminderEnabled, false)
        reminderHour = v(.reminderHour, 19)
        settingsUpdated = v(.settingsUpdated, .distantPast)
        resetAt = v(.resetAt, .distantPast)

        // Migrate first-version progress into this device's tally and the active-day list.
        if c.contains(.xp), tallies.isEmpty {
            let xp: Int = v(.xp, 0)
            let daily: [String: Int] = v(.dailyXP, [:])
            let lessons: Int = v(.lessonsDone, 0)
            let perfect: Int = v(.perfectLessons, 0)
            if xp > 0 || lessons > 0 {
                tallies[DeviceID.current] = Tally(xp: xp, lessonsDone: lessons, perfectLessons: perfect, dailyXP: daily)
            }
            activeDays.formUnion(daily.filter { $0.value > 0 }.keys)
            let streak: Int = v(.streak, 0)
            if let last: String = v(.lastActive, nil), let lastDate = Day.date(last) {
                for back in 0..<max(1, streak) { activeDays.insert(Day.key(Day.adding(-back, to: lastDate))) }
            }
            legacyLongestStreak = v(.longestStreak, 0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(words, forKey: .words)
        try c.encode(completedNodes, forKey: .completedNodes)
        try c.encode(activeDays, forKey: .activeDays)
        try c.encode(wotdCollected, forKey: .wotdCollected)
        try c.encode(wotdByDay, forKey: .wotdByDay)
        try c.encode(extraWords, forKey: .extraWords)
        try c.encode(guesses, forKey: .guesses)
        try c.encode(tallies, forKey: .tallies)
        try c.encode(legacyLongestStreak, forKey: .legacyLongestStreak)
        try c.encode(dailyGoal, forKey: .dailyGoal)
        try c.encode(reminderEnabled, forKey: .reminderEnabled)
        try c.encode(reminderHour, forKey: .reminderHour)
        try c.encode(settingsUpdated, forKey: .settingsUpdated)
        try c.encode(resetAt, forKey: .resetAt)
    }
}

/// A stable id for this install, shared by the app and its widget.
enum DeviceID {
    static let current: String = {
        let key = "rootle.deviceID"
        if let id = SharedStore.defaults.string(forKey: key) { return id }
        let id = UUID().uuidString
        SharedStore.defaults.set(id, forKey: key)
        return id
    }()
}

enum SharedStore {
    private static let key = "rootle.progress.v1"

    static var groupID: String? {
        Bundle.main.object(forInfoDictionaryKey: "RootleAppGroup") as? String
    }

    static var defaults: UserDefaults {
        if let id = groupID, let d = UserDefaults(suiteName: id) { return d }
        return .standard
    }

    static func load() -> ProgressState {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(ProgressState.self, from: data) else { return ProgressState() }
        return state
    }

    static func save(_ state: ProgressState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }
}
