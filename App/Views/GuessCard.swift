import SwiftUI

/// One multiple-choice question asked before a new word's story is revealed:
/// either what it first meant, or which language it came from.
struct GuessQuestion {
    enum Kind { case meaning, language }
    let kind: Kind
    let prompt: String
    let options: [String]
    let answer: String

    /// The same word always gets the same question and options, so reopening it doesn't reshuffle.
    init(word: Word, lexicon: Lexicon) {
        var rng = SplitMix64(seed: UInt64(truncatingIfNeeded: word.id.unicodeScalars.reduce(5381) { ($0 &* 33) &+ Int($1.value) }))
        let languages = Array(Set(lexicon.origins.filter { $0 != word.origin })).sorted()
        let useLanguage = languages.count >= 3 && rng.next() % 3 == 0
        if useLanguage {
            kind = .language
            prompt = "Which language did **\(word.word)** come from?"
            answer = word.origin
            options = ([word.origin] + Array(languages.shuffled(using: &rng).prefix(3))).shuffled(using: &rng)
        } else {
            kind = .meaning
            prompt = "What did **\(word.word)** first mean?"
            answer = word.lit
            let others = lexicon.ordered.filter { $0.id != word.id && $0.lit.lowercased() != word.lit.lowercased() }
                .map(\.lit)
            options = ([word.lit] + Array(Set(others).sorted().shuffled(using: &rng).prefix(3))).shuffled(using: &rng)
        }
    }
}

struct GuessCard: View {
    let question: GuessQuestion
    @Binding var picked: String?
    let onAnswer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                Image(picked == nil ? "digby_dig" : (picked == question.answer ? "digby_cheer" : "digby_oops"))
                    .resizable().scaledToFit().frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Overline(question.kind == .meaning ? "Guess the original meaning" : "Guess the source", color: Palette.ember)
                    md(question.prompt)
                        .font(.serif(22, .regular))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(spacing: 10) {
                ForEach(question.options, id: \.self) { option in
                    OptionTile(selected: false, state: state(for: option)) {
                        guard picked == nil else { return }
                        picked = option
                        onAnswer(option == question.answer)
                    } label: {
                        HStack {
                            Text(question.kind == .meaning ? "“\(option)”" : option)
                                .font(question.kind == .meaning ? .serif(18, .semibold).italic() : .ui(17, .bold))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            if picked != nil && option == question.answer {
                                Image(systemName: "checkmark.circle.fill")
                            } else if picked == option {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                    }
                }
            }
            if let picked {
                Text(picked == question.answer ? "Spot on! +2 XP. Here’s the whole story." : "Not quite — here’s where it really came from.")
                    .font(.ui(15, .bold))
                    .foregroundStyle(picked == question.answer ? Palette.mossShade : Palette.emberShade)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.35), value: picked)
    }

    private func state(for option: String) -> TileState {
        guard let picked else { return .normal }
        if option == question.answer { return .correct }
        if option == picked { return .wrong }
        return .disabled
    }
}
