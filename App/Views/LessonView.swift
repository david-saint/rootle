import SwiftUI

struct LessonView: View {
    let request: LessonRequest
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var session: LessonSession
    @State private var pick: String?
    @State private var arranged: [Int] = []
    @State private var matchedAll = false
    @State private var feedback: Feedback?
    @State private var summary: LessonSummary?
    @State private var confirmQuit = false
    @State private var goodTick = 0
    @State private var badTick = 0

    struct Feedback {
        let correct: Bool
        let answer: String?
        let note: String?
    }

    init(request: LessonRequest) {
        self.request = request
        _session = State(initialValue: LessonSession(exercises: request.exercises))
    }

    var body: some View {
        Group {
            if let summary {
                LessonCompleteView(summary: summary) { dismiss() }
            } else if session.isDone {
                Color.clear
            } else {
                playing
            }
        }
        .background(Palette.paper)
        .sensoryFeedback(.success, trigger: goodTick)
        .sensoryFeedback(.error, trigger: badTick)
    }

    private var playing: some View {
        let ex = session.current
        return VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 14)

            ScrollView {
                ExerciseView(exercise: ex, pick: $pick, arranged: $arranged, matchedAll: $matchedAll, locked: feedback != nil)
                    .id(ex.id)
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                    .padding(.bottom, 24)
                    .pageWidth(600)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .scrollBounceBehavior(.basedOnSize)

            bottomBar
        }
        .confirmationDialog("Leave this lesson?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { dismiss() }
            Button("Keep digging", role: .cancel) {}
        } message: {
            Text("You'll lose the progress from this lesson.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { confirmQuit = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Quit lesson")

            ThickProgressBar(value: session.progress)

            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                Text("\(session.combo)").monospacedDigit()
            }
            .font(.ui(15, .heavy))
            .foregroundStyle(session.combo >= 3 ? Palette.ochreShade : Palette.inkSoft.opacity(0.6))
            .scaleEffect(session.combo >= 3 ? 1.1 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.5), value: session.combo)
            .accessibilityLabel("Combo \(session.combo)")
        }
        .pageWidth(640)
    }

    // MARK: Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if let feedback {
            FeedbackPanel(feedback: feedback, word: session.current.word) { advance() }
                .transition(.move(edge: .bottom))
        } else {
            VStack {
                Button(checkTitle) { check() }
                    .buttonStyle(session.current.kind == .intro || session.current.kind == .match ? .chunkyMoss : .chunky)
                    .disabled(!ready)
                    .keyboardShortcut(.defaultAction)
                    .pageWidth(600)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1.5) }
        }
    }

    private var checkTitle: String {
        switch session.current.kind {
        case .intro: "Got it"
        case .match: "Continue"
        default: "Check"
        }
    }

    private var ready: Bool {
        let ex = session.current
        switch ex.kind {
        case .intro: return true
        case .match: return matchedAll
        case .build, .journey: return arranged.count == ex.solution.count
        default: return pick != nil
        }
    }

    private func check() {
        let ex = session.current
        switch ex.kind {
        case .intro, .match:
            session.record(correct: true)
            advance()
            return
        case .build, .journey:
            let ok = arranged == ex.solution
            let answer = ex.solution.compactMap { id in ex.tiles.first { $0.id == id }?.text }
                .joined(separator: ex.kind == .build ? " + " : "  →  ")
            finish(ok, answer: answer, note: ex.explanation)
        default:
            let ok = pick == ex.answer
            finish(ok, answer: ex.answer, note: ex.explanation)
        }
    }

    private func finish(_ ok: Bool, answer: String, note: String?) {
        let ex = session.current
        session.record(correct: ok)
        store.recordAnswer(wordID: ex.word?.id, correct: ok)
        if ok { goodTick += 1 } else { badTick += 1 }
        withAnimation(.spring(duration: 0.35)) {
            feedback = Feedback(correct: ok, answer: ok ? nil : answer, note: note)
        }
    }

    private func advance() {
        withAnimation(.spring(duration: 0.4)) {
            feedback = nil
            pick = nil
            arranged = []
            matchedAll = false
            session.advance()
        }
        if session.isDone {
            let result = store.completeLesson(request, session: session)
            withAnimation(.spring(duration: 0.5)) { summary = result }
        }
    }
}

// MARK: - Feedback

private struct FeedbackPanel: View {
    let feedback: LessonView.Feedback
    let word: Word?
    let next: () -> Void

    private static let praise = ["Nicely dug!", "Unearthed!", "Spot on!", "Rooted!", "Brilliant!", "Exactly right!"]
    @State private var title = ""

    var body: some View {
        let tint = feedback.correct ? Palette.moss : Palette.ember
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(feedback.correct ? "digby_cheer" : "digby_oops")
                    .resizable().scaledToFit()
                    .frame(width: 74, height: 74)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.serif(24, .bold))
                        .foregroundStyle(tint)
                    if let answer = feedback.answer {
                        md("Answer: **\(answer)**")
                            .font(.ui(15, .medium))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let note = feedback.note {
                        md(note)
                            .font(.serif(16, .regular))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let word {
                        md("**\(word.word)** · literally *“\(word.lit)”*")
                            .font(.serif(16, .regular))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            Button("Continue", action: next)
                .buttonStyle(feedback.correct ? .chunkyMoss : .chunky)
                .keyboardShortcut(.defaultAction)
        }
        .pageWidth(600)
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .background(feedback.correct ? Palette.correctWash : Palette.wrongWash)
        .onAppear {
            title = feedback.correct ? Self.praise.randomElement()! : "Not quite"
        }
    }
}
