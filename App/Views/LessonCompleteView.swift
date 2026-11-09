import SwiftUI

struct LessonCompleteView: View {
    let summary: LessonSummary
    let done: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ZStack {
                        Image("scene_treasure")
                            .resizable().scaledToFit()
                            .frame(maxWidth: 300)
                        Image("digby_cheer")
                            .resizable().scaledToFit()
                            .frame(width: 128)
                            .offset(x: 108, y: 40)
                            .scaleEffect(appeared ? 1 : 0.4)
                            .opacity(appeared ? 1 : 0)
                    }
                    .padding(.top, 20)

                    Text(summary.perfect ? "Flawless dig!" : "Lesson complete!")
                        .font(.serif(36, .black))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 8)
                    if summary.streakGrew {
                        Label("\(summary.streak)-day streak — your roots grew", systemImage: "leaf.fill")
                            .font(.ui(16, .bold))
                            .foregroundStyle(Palette.moss)
                            .padding(.top, 8)
                    }

                    HStack(spacing: 0) {
                        stat("\(summary.xp)", "XP earned", Palette.ochreShade, "star.fill")
                        divider
                        stat("\(Int((summary.accuracy * 100).rounded()))%", "Accuracy", Palette.moss, "scope")
                        divider
                        stat("\(summary.bestCombo)", "Best combo", Palette.ember, "bolt.fill")
                    }
                    .padding(.vertical, 18)
                    .padding(.top, 26)

                    if !summary.newWords.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Overline("Added to your lexicon")
                            ForEach(summary.newWords) { w in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    LanguageDot(language: w.origin, size: 10)
                                    Text(w.word).font(.serif(22, .bold)).foregroundStyle(Palette.ink)
                                    Text("“\(w.lit)”").font(.serif(16, .regular)).italic()
                                        .foregroundStyle(Palette.inkSoft)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 26)
                    }
                }
                .padding(.horizontal, 26)
                .pageWidth(560)
            }

            Button("Continue", action: done)
                .buttonStyle(.chunkyMoss)
                .keyboardShortcut(.defaultAction)
                .pageWidth(560)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
        }
        .background(Palette.paper)
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.5).delay(0.2)) { appeared = true }
        }
    }

    private var divider: some View {
        Rectangle().fill(Palette.line).frame(width: 1.5, height: 52)
    }

    private func stat(_ value: String, _ label: String, _ tint: Color, _ symbol: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 18, weight: .bold))
                Text(value).font(.serif(30, .black)).monospacedDigit()
            }
            .foregroundStyle(tint)
            Text(label).font(.ui(13, .semibold)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}
