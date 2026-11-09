import SwiftUI

struct LexiconView: View {
    @Environment(GameStore.self) private var store
    @State private var showAll = false
    @State private var query = ""
    @State private var detail: Word?

    var body: some View {
        let learned = store.learnedWords
        let lex = store.lexicon
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Lexicon")
                                .font(.serif(40, .black))
                                .foregroundStyle(Palette.ink)
                            Text(learned.isEmpty
                                 ? "Every word you dig up is kept here."
                                 : "\(learned.count) of \(lex.ordered.count) words unearthed")
                                .font(.ui(16, .medium))
                                .foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                        Image("digby_read").resizable().scaledToFit().frame(width: 96)
                            .accessibilityHidden(true)
                    }

                    if !learned.isEmpty {
                        LanguageMix(words: learned).padding(.top, 26)
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkSoft)
                            TextField("Search words or meanings", text: $query)
                                .textFieldStyle(.plain)
                                .font(.ui(16, .medium))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line, lineWidth: 1.5))

                        Picker("Show", selection: $showAll) {
                            Text("Mine").tag(false)
                            Text("All").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 130)
                    }
                    .padding(.top, 28)

                    let shown = filtered(showAll ? lex.ordered : learned)
                    if shown.isEmpty {
                        empty.padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 14)], spacing: 14) {
                            ForEach(shown) { w in
                                let known = store.isLearned(w)
                                WordTile(word: w, known: known, strength: store.strength(of: w))
                                    .onTapGesture { if known { detail = w } }
                            }
                        }
                        .padding(.top, 22)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .pageWidth(760)
            }
            .background(Palette.paper)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .sheet(item: $detail) { WordDetailView(word: $0) }
    }

    private func filtered(_ words: [Word]) -> [Word] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return words }
        return words.filter {
            store.isLearned($0) && ($0.word.lowercased().contains(q) || $0.def.lowercased().contains(q) ||
                                    $0.lit.lowercased().contains(q) || $0.origin.lowercased().contains(q))
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image("digby_dig").resizable().scaledToFit().frame(width: 140)
            Text(query.isEmpty ? "Nothing dug up yet" : "No matches")
                .font(.serif(22, .bold)).foregroundStyle(Palette.ink)
            Text(query.isEmpty ? "Finish your first lesson, or add today's word of the day." : "Try another word or language.")
                .font(.ui(15, .medium)).foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A stacked bar of where your words come from.
private struct LanguageMix: View {
    let words: [Word]

    var body: some View {
        let counts = Dictionary(grouping: words, by: \.origin).mapValues(\.count)
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        VStack(alignment: .leading, spacing: 12) {
            Overline("Where your words come from")
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(counts, id: \.key) { lang, n in
                        Rectangle()
                            .fill(Palette.language(lang))
                            .frame(width: max(6, (geo.size.width - CGFloat(counts.count - 1) * 3) * CGFloat(n) / CGFloat(words.count)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(height: 14)
            FlowLayout(spacing: 16, lineSpacing: 8) {
                ForEach(counts, id: \.key) { lang, n in
                    HStack(spacing: 6) {
                        LanguageDot(language: lang)
                        Text(lang).font(.ui(13, .semibold)).foregroundStyle(Palette.ink)
                        Text("\(n)").font(.ui(13, .bold)).foregroundStyle(Palette.inkSoft).monospacedDigit()
                    }
                }
            }
        }
    }
}

private struct WordTile: View {
    let word: Word
    let known: Bool
    let strength: Int

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            if known {
                HStack {
                    Text(word.origin.uppercased())
                        .font(.ui(10.5, .heavy)).tracking(1)
                        .foregroundStyle(Palette.language(word.origin))
                    Spacer()
                    RootStrength(level: strength).scaleEffect(0.7, anchor: .trailing)
                }
                Text(word.word)
                    .font(.serif(23, .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.55)
                Text("“\(word.lit)”")
                    .font(.serif(14.5, .regular)).italic()
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("?")
                    .font(.serif(34, .black))
                    .foregroundStyle(Palette.stratumShade)
                Text("Still buried")
                    .font(.ui(13, .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(known ? Palette.card : Palette.sunk)
        .overlay(alignment: .top) {
            if known { Palette.language(word.origin).frame(height: 6) }
        }
        .clipShape(shape)
        .overlay {
            if known { shape.strokeBorder(Palette.line, lineWidth: 1.5) }
            else { shape.strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])) }
        }
        .contentShape(shape)
        .accessibilityElement(children: .combine)
    }
}
