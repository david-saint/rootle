import SwiftUI

struct WordDetailView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let word: Word
    var isWordOfTheDay = false
    @State private var celebrate = 0
    @State private var oops = 0
    @State private var picked: String?
    /// Set once on appear, so the story stays hidden until this visit's guess is answered.
    @State private var asking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if asking {
                    GuessCard(question: GuessQuestion(word: word, lexicon: store.lexicon), picked: $picked) { right in
                        store.recordGuess(word, correct: right)
                        if right { celebrate += 1 } else { oops += 1 }
                    }
                    .padding(.top, 30)
                }
                if !asking || picked != nil {
                    revealed
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .pageWidth(620)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: picked)
        }
        .onAppear { asking = store.needsGuess(word) }
        .sensoryFeedback(.error, trigger: oops)
        .background(Palette.paper)
        .overlay(alignment: .topTrailing) { closeButton }
        .sensoryFeedback(.success, trigger: celebrate)
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 620, minHeight: 640, idealHeight: 820)
        #endif
    }

    private var revealed: some View {
        VStack(alignment: .leading, spacing: 0) {
                literally.padding(.top, asking ? 34 : 26)
                if !word.parts.isEmpty { parts.padding(.top, 34) }
                journey.padding(.top, 40)
                story.padding(.top, 40)
                if let myth = word.myth { mythPanel(myth).padding(.top, 30) }
                example.padding(.top, 34)
                if !word.related.isEmpty { related.padding(.top, 34) }
                footer.padding(.top, 40)
        }
    }

    private var closeButton: some View {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 34, height: 34)
                    .background(Palette.card, in: Circle())
                    .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .padding(16)
            .accessibilityLabel("Close")
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                let showOrigin = !asking || picked != nil
                if isWordOfTheDay { Overline("Word of the day", color: Palette.ember) }
                if isWordOfTheDay && showOrigin { Text("·").foregroundStyle(Palette.inkSoft) }
                if showOrigin {
                    Overline("From \(word.origin)", color: Palette.language(word.origin))
                }
            }
            Text(word.word)
                .font(.serif(58, .black))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            Text("\(word.pron)  ·  \(word.pos)")
                .font(.ui(15, .medium))
                .foregroundStyle(Palette.inkSoft)
            Text(word.def.prefix(1).capitalized + word.def.dropFirst() + ".")
                .font(.serif(22, .regular))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
        .padding(.trailing, 30)
    }

    private var literally: some View {
        HStack(alignment: .center, spacing: 16) {
            Rectangle().fill(Palette.ember).frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text("Literally").font(.serif(15, .regular)).italic().foregroundStyle(Palette.inkSoft)
                Text("“\(word.lit)”")
                    .font(.serif(30, .semibold)).italic()
                    .foregroundStyle(Palette.ember)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var parts: some View {
        VStack(alignment: .leading, spacing: 14) {
            Overline("Taken apart")
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(word.parts.enumerated()), id: \.offset) { i, part in
                    if i > 0 {
                        Text("+").font(.serif(26, .regular)).foregroundStyle(Palette.inkSoft).padding(.top, 8)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(part.p)
                            .font(.serif(24, .bold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line, lineWidth: 1.5))
                        Text(part.m)
                            .font(.ui(13, .medium))
                            .foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Modern English at the surface; dig down through older and older layers.
    private var journey: some View {
        VStack(alignment: .leading, spacing: 14) {
            Overline("Dig down through time")
            let steps = Array(word.journey.reversed())
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 16) {
                        Text(step.date)
                            .font(.ui(12, .bold))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(width: 76, alignment: .trailing)
                            .padding(.top, 6)
                        ZStack(alignment: .top) {
                            Rectangle()
                                .fill(Palette.layer(i + 1).deep)
                                .frame(width: 2)
                                .opacity(i == steps.count - 1 ? 0 : 1)
                                .padding(.top, 14)
                            Circle()
                                .fill(Palette.language(step.lang))
                                .frame(width: 16, height: 16)
                                .overlay(Circle().strokeBorder(Palette.paper, lineWidth: 3))
                                .padding(.top, 5)
                        }
                        .frame(width: 16)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.lang)
                                .font(.ui(12, .heavy)).tracking(0.6)
                                .foregroundStyle(Palette.language(step.lang))
                            Text(step.form)
                                .font(.serif(22, .semibold)).italic()
                                .foregroundStyle(Palette.ink)
                            Text(step.gloss)
                                .font(.ui(14, .medium))
                                .foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.bottom, 22)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .padding(.trailing, 12)
                    .background(Palette.layer(i + 1).fill)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var story: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Overline("The story")
                Text(word.story)
                    .font(.serif(19, .regular))
                    .lineSpacing(6)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Image("digby_read")
                .resizable().scaledToFit()
                .frame(width: 92)
                .padding(.top, 20)
                .accessibilityHidden(true)
        }
    }

    private func mythPanel(_ myth: Myth) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.seal.fill").foregroundStyle(Palette.ember)
                Overline("Myth", color: Palette.ember)
            }
            Text(myth.claim)
                .font(.serif(18, .regular))
                .strikethrough(color: Palette.ember.opacity(0.7))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.moss)
                Overline("Truth", color: Palette.moss)
            }
            .padding(.top, 4)
            Text(myth.truth)
                .font(.serif(18, .semibold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.wrongWash.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var example: some View {
        VStack(alignment: .leading, spacing: 10) {
            Overline("In a sentence")
            Text(highlighted(word.example))
                .font(.serif(20, .regular)).italic()
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var related: some View {
        VStack(alignment: .leading, spacing: 12) {
            Overline("Relatives")
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(word.related, id: \.self) { r in
                    Text(r)
                        .font(.ui(14, .semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1.5))
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if store.canCollect(word) {
            Button {
                store.collect(word)
                celebrate += 1
            } label: {
                Label("Add to my lexicon  ·  +\(word.id == store.wordOfTheDay.id ? 5 : 3) XP", systemImage: "plus")
            }
            .buttonStyle(.chunky)
        } else if store.isLearned(word) {
            HStack(spacing: 12) {
                RootStrength(level: store.strength(of: word))
                VStack(alignment: .leading, spacing: 2) {
                    Text("In your lexicon").font(.ui(15, .bold)).foregroundStyle(Palette.moss)
                    Text(strengthText).font(.ui(13, .medium)).foregroundStyle(Palette.inkSoft)
                }
            }
        }
    }

    private var strengthText: String {
        switch store.strength(of: word) {
        case 0...1: "Freshly planted — review it soon."
        case 2...3: "Taking root."
        default: "Deeply rooted."
        }
    }

    private func highlighted(_ sentence: String) -> AttributedString {
        var a = AttributedString(sentence)
        if let r = a.range(of: word.word, options: .caseInsensitive) ?? a.range(of: String(word.word.prefix(4)), options: .caseInsensitive) {
            a[r].foregroundColor = Palette.ember
        }
        return a
    }
}

/// Five little roots that fill in as a word moves through spaced repetition.
struct RootStrength: View {
    let level: Int
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Capsule()
                    .fill(i <= level ? Palette.moss : Palette.line)
                    .frame(width: 5, height: CGFloat(8 + i * 4))
            }
        }
        .accessibilityLabel("Memory strength \(level) of 5")
    }
}
