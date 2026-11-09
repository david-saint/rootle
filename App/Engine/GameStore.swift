import SwiftUI
import Observation
import WidgetKit

enum NodeStatus { case done, current, locked }

struct LessonSummary {
    let xp: Int
    let accuracy: Double
    let bestCombo: Int
    let newWords: [Word]
    let streak: Int
    let streakGrew: Bool
    let perfect: Bool
}

struct Badge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let earned: Bool
}

@Observable
final class GameStore {
    enum Dig: Equatable { case idle, layer, words }

    private(set) var state: ProgressState
    private(set) var lexicon = Lexicon.shared
    /// What Claude is digging up right now, if anything.
    private(set) var digging: Dig = .idle
    var digError: String?

    init() {
        state = SharedStore.load()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedDemo") { seedDemo() }
        if ProcessInfo.processInfo.arguments.contains("-clearDemo") {
            // Wipes local progress as if never played, without overriding other devices.
            state = ProgressState()
            SharedStore.save(state)
        }
        #endif
        pinToday()
    }

    /// Fixes today's word of the day so the growing lexicon never reshuffles it. Call when the app becomes active.
    func pinToday() {
        Lexicon.reload()
        lexicon = .shared
        let today = Day.key()
        guard state.wotdByDay[today] == nil else { return }
        state.wotdByDay[today] = state.wordOfTheDay(in: lexicon).id
        persist()
    }

    #if DEBUG
    /// Fills in a believable couple of weeks of play, for screenshots and testing.
    private func seedDemo() {
        var s = ProgressState()
        let nodes = lexicon.nodes.prefix(10)
        s.completedNodes = Set(nodes.map(\.id))
        let ids = Set(nodes.flatMap(\.wordIDs)).union(["petrichor", "robot", "avocado"])
        for (i, id) in ids.sorted().enumerated() {
            s.words[id] = WordProgress(box: 1 + i % 5, due: Day.key(daysFromNow: i % 4 - 1), seen: 4, correct: 3, learnedOn: Day.key(daysFromNow: -12))
        }
        for back in 0..<12 {
            s.addXP([24, 31, 18, 42, 27, 35, 22, 30, 26, 19, 33, 28][back], on: Day.key(daysFromNow: -back))
            s.activeDays.insert(Day.key(daysFromNow: -back))
        }
        for i in 0..<14 { s.countLesson(perfect: i < 3) }
        s.wotdCollected = Set((1..<9).map { Day.key(daysFromNow: -$0) })
        state = s
        persist()
    }
    #endif

    private func persist(upload: Bool = true) {
        SharedStore.save(state)
        WidgetCenter.shared.reloadAllTimelines()
        if upload { MainActor.assumeIsolated { CloudSync.shared.progressChanged() } }
    }

    /// Folds in progress from another device. Returns true if our copy has anything theirs lacks.
    @discardableResult
    func mergeRemote(_ remote: ProgressState) -> Bool {
        let merged = state.merged(with: remote)
        if merged != state {
            state = merged
            persist(upload: false)
            Reminders.reschedule(enabled: state.reminderEnabled, hour: state.reminderHour)
        }
        return merged != remote
    }

    /// Picks up words and layers that arrived from another device.
    func lexiconChanged() {
        lexicon = .shared
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Derived

    var streak: Int { state.liveStreak() }
    var xpToday: Int { state.xpToday() }
    var goalProgress: Double { min(1, Double(xpToday) / Double(max(1, state.dailyGoal))) }
    var learnedWords: [Word] { lexicon.ordered.filter { state.words[$0.id] != nil } }
    func isLearned(_ word: Word) -> Bool { state.words[word.id] != nil }
    func strength(of word: Word) -> Int { state.words[word.id]?.box ?? 0 }

    var currentNodeID: String? {
        lexicon.nodes.first { !state.completedNodes.contains($0.id) }?.id
    }

    func status(of node: PathNode) -> NodeStatus {
        if state.completedNodes.contains(node.id) { return .done }
        if node.id == currentNodeID { return .current }
        return .locked
    }

    func isUnitLocked(_ index: Int) -> Bool {
        guard let first = lexicon.nodes(forUnit: index).first else { return true }
        return status(of: first) == .locked
    }

    func unitProgress(_ index: Int) -> (done: Int, total: Int) {
        let nodes = lexicon.nodes(forUnit: index)
        return (nodes.filter { state.completedNodes.contains($0.id) }.count, nodes.count)
    }

    /// Learned words whose review is due today or earlier.
    var dueWords: [Word] {
        let today = Day.key()
        return learnedWords.filter { (state.words[$0.id]?.due ?? today) <= today }
    }

    var wordOfTheDay: Word { state.wordOfTheDay(in: lexicon) }
    var collectedWordOfTheDay: Bool { state.wotdCollected.contains(Day.key()) || isLearned(wordOfTheDay) }

    /// Extra words dug up today, beyond the word of the day.
    var extrasToday: [Word] { (state.extraWords[Day.key()] ?? []).compactMap { lexicon.word($0) } }

    /// Today's finds can be added to the lexicon straight from their detail page.
    func canCollect(_ word: Word) -> Bool {
        !isLearned(word) && (word.id == wordOfTheDay.id || state.extraWords[Day.key()]?.contains(word.id) == true)
    }

    /// New finds ask for a guess before showing where they came from.
    func needsGuess(_ word: Word) -> Bool {
        state.guesses[word.id] == nil && canCollect(word)
    }

    /// Records a guess-the-origin answer: +2 XP for a right guess.
    func recordGuess(_ word: Word, correct: Bool) {
        guard state.guesses[word.id] == nil else { return }
        state.guesses[word.id] = correct
        if correct { addXP(2) }
        touchStreak()
        persist()
    }

    /// Words still waiting to be found: not yet a daily word, an extra or learned.
    var unusedCount: Int { lexicon.unusedWords(state: state).count }
    var isLastLayer: Bool {
        guard let id = currentNodeID, let node = lexicon.nodes.first(where: { $0.id == id }) else { return true }
        return node.unitIndex >= lexicon.units.count - 1
    }

    /// XP for each of the last seven days, oldest first.
    var week: [(label: String, xp: Int, isToday: Bool)] {
        let f = DateFormatter(); f.dateFormat = "EEEEE"
        return (0..<7).reversed().map { back in
            let d = Day.adding(-back)
            return (f.string(from: d), state.dailyXP[Day.key(d)] ?? 0, back == 0)
        }
    }

    // MARK: Actions

    private func addXP(_ n: Int) {
        state.addXP(n)
    }

    /// Marks today as active; returns true if the streak grew.
    @discardableResult
    private func touchStreak() -> Bool {
        state.markActive()
    }

    private func learn(_ id: String) {
        guard state.words[id] == nil else { return }
        state.words[id] = WordProgress(box: 1, due: Day.key(daysFromNow: 1), learnedOn: Day.key())
    }

    /// Spaced-repetition update for words already in the lexicon.
    func recordAnswer(wordID: String?, correct: Bool) {
        guard let id = wordID, var p = state.words[id] else { return }
        p.seen += 1
        if correct {
            p.correct += 1
            p.box = min(5, p.box + 1)
        } else {
            p.box = max(1, p.box - 2)
        }
        p.due = Day.key(daysFromNow: max(1, WordProgress.intervals[p.box]))
        state.words[id] = p
        // Saved at the end of the lesson.
    }

    func collectWordOfTheDay() { collect(wordOfTheDay) }

    /// Adds one of today's finds to the lexicon: +5 XP for the word of the day, +3 for extras.
    func collect(_ word: Word) {
        guard canCollect(word) else { return }
        let isDaily = word.id == wordOfTheDay.id
        if isDaily { state.wotdCollected.insert(Day.key()) }
        learn(word.id)
        addXP(isDaily ? 5 : 3)
        touchStreak()
        persist()
    }

    // MARK: Digging up new words

    /// Adds another word to today's finds, asking Claude for fresh ones when the supply runs low.
    @MainActor
    func digUpAnotherWord() async {
        if lexicon.unusedWords(state: state).filter({ $0.id != wordOfTheDay.id }).isEmpty {
            await forgeLooseWords()
        }
        let pool = lexicon.unusedWords(state: state).filter { $0.id != wordOfTheDay.id }
        guard let pick = pool.randomElement() else { return }
        state.extraWords[Day.key(), default: []].append(pick.id)
        persist()
        Task { await keepRunway() }
    }

    /// Asks Claude for a whole new dig-site layer.
    @MainActor
    func digNewLayer() async {
        guard digging == .idle else { return }
        guard WordForge.isAvailable else { digError = WordForge.Failure.noKey.errorDescription; return }
        digging = .layer
        defer { digging = .idle }
        do {
            let (unit, words) = try await WordForge.newLayer(lexicon: lexicon)
            try GeneratedLexicon.append(units: [unit], words: words)
            lexicon = .shared
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            digError = error.localizedDescription
        }
    }

    @MainActor
    private func forgeLooseWords() async {
        guard digging == .idle else { return }
        guard WordForge.isAvailable else { digError = WordForge.Failure.noKey.errorDescription; return }
        digging = .words
        defer { digging = .idle }
        do {
            let words = try await WordForge.looseWords(count: 6, lexicon: lexicon)
            try GeneratedLexicon.append(words: words)
            lexicon = .shared
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            digError = error.localizedDescription
        }
    }

    /// Keeps the lexicon growing ahead of the player: a new layer once they reach the deepest one,
    /// and a fresh batch of words before the daily supply runs dry. Quiet on failure.
    @MainActor
    func keepRunway() async {
        guard WordForge.isAvailable, digging == .idle else { return }
        let hadError = digError
        if isLastLayer {
            await digNewLayer()
        } else if unusedCount < 5 {
            await forgeLooseWords()
        }
        if hadError == nil { digError = nil }
    }

    func completeLesson(_ request: LessonRequest, session: LessonSession) -> LessonSummary {
        let perfect = session.answered > 0 && session.mistakes == 0
        var xp = session.xp + 10
        if perfect { xp += 5 }
        addXP(xp)
        let fresh = request.newWordIDs.filter { state.words[$0] == nil }
        fresh.forEach(learn)
        if let node = request.nodeID { state.completedNodes.insert(node) }
        state.countLesson(perfect: perfect)
        let grew = touchStreak()
        persist()
        return LessonSummary(
            xp: xp,
            accuracy: session.answered == 0 ? 1 : Double(session.firstTryCorrect) / Double(session.answered - session.retries),
            bestCombo: session.bestCombo,
            newWords: fresh.compactMap { lexicon.word($0) },
            streak: state.liveStreak(),
            streakGrew: grew,
            perfect: perfect)
    }

    func setDailyGoal(_ goal: Int) { state.dailyGoal = goal; state.settingsUpdated = .now; persist() }

    func setReminder(enabled: Bool, hour: Int) {
        state.reminderEnabled = enabled
        state.reminderHour = hour
        state.settingsUpdated = .now
        persist()
        Reminders.reschedule(enabled: enabled, hour: hour)
    }

    func resetProgress() {
        let settings = state
        state = ProgressState()
        state.dailyGoal = settings.dailyGoal
        state.reminderEnabled = settings.reminderEnabled
        state.reminderHour = settings.reminderHour
        state.settingsUpdated = settings.settingsUpdated
        state.resetAt = .now // wins over older progress on other devices
        persist()
    }

    // MARK: Badges

    var badges: [Badge] {
        let learnedCount = state.words.count
        let origins = Set(learnedWords.map(\.origin)).count
        return [
            Badge(id: "first", title: "First Dig", detail: "Finish a lesson", symbol: "hammer.fill", earned: state.lessonsDone >= 1),
            Badge(id: "sprout", title: "Sprouting", detail: "3-day streak", symbol: "leaf.fill", earned: state.longestStreak >= 3),
            Badge(id: "week", title: "Week of Roots", detail: "7-day streak", symbol: "calendar", earned: state.longestStreak >= 7),
            Badge(id: "oak", title: "Old Oak", detail: "30-day streak", symbol: "tree.fill", earned: state.longestStreak >= 30),
            Badge(id: "flawless", title: "Flawless", detail: "A perfect lesson", symbol: "sparkles", earned: state.perfectLessons >= 1),
            Badge(id: "hoard", title: "Word Hoard", detail: "25 words unearthed", symbol: "books.vertical.fill", earned: learnedCount >= 25),
            Badge(id: "polyglot", title: "Globetrotter", detail: "Words from 8 languages", symbol: "globe.europe.africa.fill", earned: origins >= 8),
            Badge(id: "early", title: "Daily Reader", detail: "7 words of the day", symbol: "sun.max.fill", earned: state.wotdCollected.count >= 7),
            Badge(id: "lexicographer", title: "Lexicographer", detail: "Every word unearthed", symbol: "crown.fill", earned: learnedCount >= lexicon.ordered.count),
        ]
    }
}
