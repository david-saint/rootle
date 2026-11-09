import SwiftUI

struct ExerciseView: View {
    let exercise: Exercise
    @Binding var pick: String?
    @Binding var arranged: [Int]
    @Binding var matchedAll: Bool
    let locked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if exercise.kind == .intro, let w = exercise.word {
                IntroCard(word: w)
            } else {
                HStack(spacing: 7) {
                    Image(systemName: exercise.kind.symbol)
                    Text(exercise.isRetry ? "Second chance" : exercise.kind.label)
                }
                .font(.ui(13, .heavy))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(exercise.isRetry ? Palette.ember : Palette.teal)

                PromptBubble(text: exercise.prompt)

                switch exercise.kind {
                case .factOrFib:
                    FactOrFib(options: exercise.options, pick: $pick, reveal: locked ? exercise.answer : nil)
                case .build, .journey:
                    Arranger(exercise: exercise, arranged: $arranged, locked: locked)
                case .match:
                    MatchBoard(pairs: exercise.pairs, matchedAll: $matchedAll)
                default:
                    Choices(options: exercise.options, serif: exercise.kind == .wordFromLiteral, pick: $pick, reveal: locked ? exercise.answer : nil)
                }
            }
        }
    }
}

// MARK: - Prompt

private struct PromptBubble: View {
    let text: String
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Image("digby_wave")
                .resizable().scaledToFit()
                .frame(width: 76)
                .accessibilityHidden(true)
            md(text)
                .font(.serif(22, .regular))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.card, in: SpeechBubble())
                .overlay(SpeechBubble().stroke(Palette.line, lineWidth: 1.5))
                .padding(.bottom, 26)
        }
    }
}

/// Rounded rectangle with a little tail pointing to Digby.
private struct SpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        var p = Path(roundedRect: rect, cornerRadius: r, style: .continuous)
        var tail = Path()
        tail.move(to: CGPoint(x: rect.minX + 1, y: rect.maxY - 30))
        tail.addLine(to: CGPoint(x: rect.minX - 12, y: rect.maxY - 10))
        tail.addLine(to: CGPoint(x: rect.minX + 1, y: rect.maxY - 16))
        tail.closeSubpath()
        p.addPath(tail)
        return p
    }
}

// MARK: - Intro card

private struct IntroCard: View {
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "sparkle")
                Text("New word unearthed")
            }
            .font(.ui(13, .heavy)).textCase(.uppercase).tracking(1.2)
            .foregroundStyle(Palette.ember)

            Text(word.word)
                .font(.serif(54, .black))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.4).lineLimit(1)
                .padding(.top, 14)
            Text("\(word.pron)  ·  \(word.pos)")
                .font(.ui(15, .medium)).foregroundStyle(Palette.inkSoft)
            Text(word.def.prefix(1).capitalized + word.def.dropFirst())
                .font(.serif(21, .regular))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            HStack(spacing: 14) {
                Rectangle().fill(Palette.ember).frame(width: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text("literally").font(.serif(14, .regular)).italic().foregroundStyle(Palette.inkSoft)
                    Text("“\(word.lit)”").font(.serif(26, .semibold)).italic().foregroundStyle(Palette.ember)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 22)

            // A compact journey: oldest → newest.
            FlowLayout(spacing: 6, lineSpacing: 10) {
                ForEach(Array(word.journey.enumerated()), id: \.offset) { i, step in
                    HStack(spacing: 6) {
                        if i > 0 { Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.inkSoft) }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.lang).font(.ui(10.5, .heavy)).foregroundStyle(Palette.language(step.lang))
                            Text(step.form).font(.serif(16, .semibold)).italic().foregroundStyle(Palette.ink)
                        }
                    }
                }
            }
            .padding(.top, 26)

            Text(word.story)
                .font(.serif(18, .regular))
                .lineSpacing(5)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 26)
        }
    }
}

// MARK: - Multiple choice

/// After checking: the right answer glows green, a wrong pick turns red, the rest fade.
private func revealState(_ option: String, pick: String?, reveal: String?) -> TileState {
    guard let reveal else { return .normal }
    if option == reveal { return .correct }
    if option == pick { return .wrong }
    return .disabled
}

private struct Choices: View {
    let options: [String]
    let serif: Bool
    @Binding var pick: String?
    let reveal: String?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                OptionTile(selected: pick == option, state: revealState(option, pick: pick, reveal: reveal)) {
                    pick = option
                } label: {
                    HStack(spacing: 14) {
                        Text("\(i + 1)")
                            .font(.ui(13, .heavy))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(width: 24, height: 24)
                            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.line, lineWidth: 1.5))
                        Text(option)
                            .font(serif ? .serif(20, .semibold) : .ui(17, .semibold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                .disabled(reveal != nil)
            }
        }
    }
}

private struct FactOrFib: View {
    let options: [String]
    @Binding var pick: String?
    let reveal: String?

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                OptionTile(selected: pick == option, state: revealState(option, pick: pick, reveal: reveal)) {
                    pick = option
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: option == "Fact" ? "checkmark.seal.fill" : "theatermasks.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(option == "Fact" ? Palette.moss : Palette.ember)
                        Text(option).font(.ui(19, .heavy))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                .disabled(reveal != nil)
            }
        }
    }
}

// MARK: - Arrange tiles (build a word / order the journey)

private struct Arranger: View {
    let exercise: Exercise
    @Binding var arranged: [Int]
    let locked: Bool

    private var isJourney: Bool { exercise.kind == .journey }
    private func tile(_ id: Int) -> Tile? { exercise.tiles.first { $0.id == id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            // Answer area
            if isJourney {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<exercise.solution.count, id: \.self) { slot in
                        HStack(spacing: 12) {
                            Text(slot == 0 ? "Oldest" : slot == exercise.solution.count - 1 ? "Newest" : "")
                                .font(.ui(11, .heavy)).textCase(.uppercase).tracking(0.8)
                                .foregroundStyle(Palette.inkSoft)
                                .frame(width: 56, alignment: .trailing)
                            if slot < arranged.count, let t = tile(arranged[slot]) {
                                chip(t, placed: true) { remove(t.id) }
                            } else {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                                    .frame(height: 58)
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    FlowLayout(spacing: 8, lineSpacing: 10) {
                        ForEach(arranged, id: \.self) { id in
                            if let t = tile(id) { chip(t, placed: true) { remove(id) } }
                        }
                    }
                    .frame(minHeight: 60, alignment: .bottomLeading)
                    Rectangle().fill(Palette.line).frame(height: 2).padding(.top, 8)
                    Text(arranged.isEmpty ? " " : arranged.compactMap { tile($0)?.text }
                        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
                        .joined())
                        .font(.serif(16, .regular)).italic()
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.top, 8)
                }
            }

            // Tile bank
            FlowLayout(spacing: 10, lineSpacing: 12) {
                ForEach(exercise.tiles) { t in
                    let used = arranged.contains(t.id)
                    chip(t, placed: false) { add(t.id) }
                        .opacity(used ? 0 : 1)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Palette.line.opacity(used ? 0.6 : 0)).padding(.bottom, 3))
                        .allowsHitTesting(!used)
                }
            }
        }
        .animation(.spring(duration: 0.3), value: arranged)
    }

    private func chip(_ t: Tile, placed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 1) {
                if isJourney, let d = t.detail {
                    Text(d).font(.ui(11, .heavy)).foregroundStyle(Palette.language(d))
                }
                Text(t.text).font(.serif(isJourney ? 18 : 20, .semibold)).italic(isJourney)
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: isJourney ? 58 : 50)
            .frame(maxWidth: isJourney && placed ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(ChipStyle())
        .disabled(locked)
    }

    private func add(_ id: Int) {
        guard arranged.count < exercise.solution.count else { return }
        arranged.append(id)
    }

    private func remove(_ id: Int) { arranged.removeAll { $0 == id } }
}

private struct ChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return configuration.label
            .background(shape.fill(Palette.card))
            .overlay(shape.strokeBorder(Palette.line, lineWidth: 2))
            .offset(y: configuration.isPressed ? 3 : 0)
            .background(shape.fill(Palette.line).offset(y: 3))
            .padding(.bottom, 3)
            .animation(.spring(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Match pairs

private struct MatchBoard: View {
    let pairs: [(left: String, right: String)]
    @Binding var matchedAll: Bool

    @State private var lefts: [String] = []
    @State private var rights: [String] = []
    @State private var selLeft: String?
    @State private var selRight: String?
    @State private var matched: Set<String> = []
    @State private var wrong: Set<String> = []

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 10) {
                ForEach(lefts, id: \.self) { l in
                    cell(l, serif: true, selected: selLeft == l) { selLeft = l; resolve() }
                }
            }
            VStack(spacing: 10) {
                ForEach(rights, id: \.self) { r in
                    cell(r, serif: false, selected: selRight == r) { selRight = r; resolve() }
                }
            }
        }
        .onAppear {
            if lefts.isEmpty {
                lefts = pairs.map(\.left).shuffled()
                rights = pairs.map(\.right).shuffled()
            }
        }
        .sensoryFeedback(.selection, trigger: matched.count)
    }

    private func cell(_ text: String, serif: Bool, selected: Bool, action: @escaping () -> Void) -> some View {
        let done = matched.contains(text)
        let bad = wrong.contains(text)
        return OptionTile(selected: selected && !done, state: done ? .correct : bad ? .wrong : .normal, action: { if !done { action() } }) {
            Text(serif ? text : "“\(text)”")
                .font(serif ? .serif(19, .bold) : .ui(14.5, .semibold))
                .italic(!serif)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .overlay(alignment: .trailing) {
                    if done { Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(Palette.moss) }
                }
        }
        .opacity(done ? 0.7 : 1)
    }

    private func resolve() {
        guard let l = selLeft, let r = selRight else { return }
        if pairs.contains(where: { $0.left == l && $0.right == r }) {
            withAnimation(.spring(duration: 0.3)) { matched.formUnion([l, r]) }
            if matched.count == pairs.count * 2 { matchedAll = true }
        } else {
            wrong = [l, r]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation { wrong = [] } }
        }
        selLeft = nil
        selRight = nil
    }
}
