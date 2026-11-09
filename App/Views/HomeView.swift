import SwiftUI

struct HomeView: View {
    @Environment(GameStore.self) private var store
    @State private var lesson: LessonRequest?
    @State private var detail: Word?
    @State private var lockedNudge: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    StatsBar()
                        .pageWidth()
                        .padding(.horizontal, 20)
                        #if os(macOS)
                        .padding(.top, 22)
                        #else
                        .padding(.top, 8)
                        #endif

                    WordOfTheDayHero { detail = $0 }
                        .pageWidth()
                        .padding(.horizontal, 20)
                        .padding(.top, 22)

                    TodaysFinds { detail = $0 }
                        .pageWidth()
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    if store.dueWords.count >= 3 {
                        PracticePrompt(count: store.dueWords.count) {
                            lesson = LessonBuilder.practice(Array(store.dueWords.shuffled().prefix(8)))
                        }
                        .pageWidth()
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                    }

                    DigSiteView(
                        onStart: { node, replay in lesson = LessonBuilder.lesson(for: node, replay: replay) },
                        onLocked: { lockedNudge = $0 }
                    )
                    .padding(.top, 36)
                }
            }
            .background(Palette.paper)
            .scrollContentBackground(.hidden)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .immersiveCover(item: $lesson) { LessonView(request: $0) }
        .sheet(item: $detail) { WordDetailView(word: $0, isWordOfTheDay: $0.id == store.wordOfTheDay.id) }
        .alert("Not yet!", isPresented: Binding(get: { lockedNudge != nil }, set: { if !$0 { lockedNudge = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lockedNudge ?? "")
        }
    }
}

// MARK: - Top bar

private struct StatsBar: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        HStack(spacing: 18) {
            #if os(iOS)
            Text("Rootle")
                .font(.serif(28, .black))
                .foregroundStyle(Palette.ink)
            #endif
            Spacer()
            stat(image: store.state.activeToday() ? "leaf.fill" : "leaf",
                 tint: store.state.activeToday() ? Palette.moss : Palette.inkSoft,
                 value: "\(store.streak)", help: "Day streak")
            stat(image: "star.fill", tint: Palette.ochre, value: "\(store.state.xp)", help: "Total XP")
            ZStack {
                GoalRing(progress: store.goalProgress, lineWidth: 4)
                Image(systemName: store.goalProgress >= 1 ? "checkmark" : "target")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(store.goalProgress >= 1 ? Palette.ochreShade : Palette.inkSoft)
            }
            .frame(width: 30, height: 30)
            .help("Daily goal: \(store.xpToday)/\(store.state.dailyGoal) XP")
        }
    }

    private func stat(image: String, tint: Color, value: String, help: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: image).foregroundStyle(tint).font(.system(size: 17, weight: .bold))
            Text(value).font(.ui(17, .heavy)).foregroundStyle(Palette.ink).monospacedDigit()
        }
        .help(help)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(help): \(value)")
    }
}

// MARK: - Word of the day

private struct WordOfTheDayHero: View {
    @Environment(GameStore.self) private var store
    let open: (Word) -> Void

    var body: some View {
        let w = store.wordOfTheDay
        let hidden = store.needsGuess(w)
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        Button { open(w) } label: {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Overline("Word of the day", color: .white.opacity(0.9))
                        Text("·").foregroundStyle(.white.opacity(0.6))
                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.ui(12, .semibold)).foregroundStyle(.white.opacity(0.75))
                    }
                    Text(w.word)
                        .font(.serif(56, .black))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.top, 12)
                    Text("\(w.pron)  ·  \(w.pos)")
                        .font(.ui(14, .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hidden ? "it once meant…" : "literally")
                            .font(.serif(14, .regular)).italic()
                            .foregroundStyle(.white.opacity(0.75))
                        Text(hidden ? "Can you guess?" : "“\(w.lit)”")
                            .font(.serif(27, .semibold)).italic()
                            .foregroundStyle(Palette.heroGold)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 130)
                    HStack(spacing: 16) {
                        if !hidden {
                            HStack(spacing: 6) {
                                Circle().fill(Palette.language(w.origin)).frame(width: 10, height: 10)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                                Text(w.origin).font(.ui(13, .heavy)).foregroundStyle(.white)
                            }
                        }
                        if hidden {
                            Text("Take a guess  →").font(.ui(14, .heavy)).foregroundStyle(.white)
                        } else if store.collectedWordOfTheDay {
                            Label("In your lexicon", systemImage: "checkmark.circle.fill")
                                .font(.ui(13, .bold)).foregroundStyle(Palette.heroGold)
                        } else {
                            Text("Dig in  →").font(.ui(14, .heavy)).foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 22)
                }
                .frame(maxWidth: .infinity, minHeight: hidden ? 250 : 0, alignment: .topLeading)
                .padding(26)

                Image("digby_read")
                    .resizable().scaledToFit()
                    .frame(width: 158)
                    .offset(x: 6, y: 12)
                    .accessibilityHidden(true)
            }
            .background {
                shape.fill(Palette.hero)
                    .overlay(alignment: .topTrailing) {
                        Circle().fill(.white.opacity(0.09)).frame(width: 280).offset(x: 90, y: -110)
                    }
                    .overlay(alignment: .bottomLeading) {
                        Circle().fill(Palette.heroGold.opacity(0.16)).frame(width: 170).offset(x: -70, y: 80)
                    }
                    .clipShape(shape)
            }
            .clipShape(shape)
            .background(shape.fill(Palette.heroShade).offset(y: 6))
            .padding(.bottom, 6)
        }
        .buttonStyle(.plain)
    }
}

/// Extra words dug up today, plus a button to dig up another.
private struct TodaysFinds: View {
    @Environment(GameStore.self) private var store
    let open: (Word) -> Void

    var body: some View {
        let extras = store.extrasToday
        VStack(alignment: .leading, spacing: 0) {
            if !extras.isEmpty {
                Overline("More finds today")
                    .padding(.bottom, 6)
                ForEach(extras) { w in
                    Button { open(w) } label: { row(w) }
                        .buttonStyle(.plain)
                    if w.id != extras.last?.id {
                        Rectangle().fill(Palette.line).frame(height: 1.5)
                    }
                }
            }
            digButton
                .padding(.top, extras.isEmpty ? 0 : 18)
        }
    }

    private func row(_ w: Word) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(w.word)
                .font(.serif(22, .bold))
                .foregroundStyle(Palette.ink)
            let hidden = store.needsGuess(w)
            Text(hidden ? "Guess its origin" : "“\(w.lit)”")
                .font(.serif(15, .regular)).italic()
                .foregroundStyle(hidden ? Palette.inkSoft : Palette.ember)
                .lineLimit(1)
            Spacer(minLength: 8)
            if store.isLearned(w) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.moss)
            } else if hidden {
                Image(systemName: "questionmark.circle.fill").foregroundStyle(Palette.ochre)
            } else {
                LanguageLabel(language: w.origin)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var digButton: some View {
        let busy = store.digging == .words
        Button {
            Task { await store.digUpAnotherWord() }
        } label: {
            HStack(spacing: 10) {
                if busy {
                    ProgressView().controlSize(.small).tint(Palette.ink)
                    Text("Digby is digging…")
                } else {
                    Image(systemName: "sparkles")
                    Text(store.extrasToday.isEmpty ? "Dig up another word" : "Dig up one more")
                }
            }
        }
        .buttonStyle(.chunkyQuiet)
        .disabled(busy || store.digging == .layer)
    }
}

private struct PracticePrompt: View {
    let count: Int
    let start: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Image("digby_dig").resizable().scaledToFit().frame(width: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) words are ready to refresh")
                    .font(.ui(16, .bold)).foregroundStyle(Palette.ink)
                Text("Review now so they take root for good.")
                    .font(.ui(13, .medium)).foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 8)
            Button("Practise", action: start)
                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, shade: Palette.tealShade, height: 42))
                .frame(width: 112)
        }
    }
}
