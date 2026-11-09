import WidgetKit
import SwiftUI

@main
struct RootleWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordOfTheDayWidget()
        StreakWidget()
    }
}

// MARK: - Timeline

struct RootleEntry: TimelineEntry {
    let date: Date
    let word: Word
    let streak: Int
    let stage: Int
    let watered: Bool
    let xpToday: Int
    let goal: Int
}

struct RootleProvider: TimelineProvider {
    func entry(at date: Date) -> RootleEntry {
        let state = SharedStore.load()
        return RootleEntry(date: date,
                           word: state.wordOfTheDay(date),
                           streak: state.liveStreak(date),
                           stage: state.growthStage(date),
                           watered: state.activeToday(date),
                           xpToday: state.xpToday(date),
                           goal: state.dailyGoal)
    }

    func placeholder(in context: Context) -> RootleEntry { entry(at: .now) }

    func getSnapshot(in context: Context, completion: @escaping (RootleEntry) -> Void) {
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RootleEntry>) -> Void) {
        Lexicon.reload() // pick up words generated since the last refresh
        let now = Date.now
        let midnight = Day.nextMidnight(after: now)
        // Today, then a fresh word at midnight, and the day after.
        let entries = [entry(at: now), entry(at: midnight), entry(at: Day.nextMidnight(after: midnight))]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

// MARK: - Word of the day

struct WordOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WordOfTheDay", provider: RootleProvider()) { entry in
            WordOfTheDayView(entry: entry)
                .containerBackground(for: .widget) { Palette.paper }
                .widgetURL(URL(string: "rootle://word/\(entry.word.id)"))
        }
        .configurationDisplayName("Word of the Day")
        .description("A new word every day, with where it came from.")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
        #else
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        #endif
    }
}

struct WordOfTheDayView: View {
    let entry: RootleEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let w = entry.word
        switch family {
        #if os(iOS)
        case .accessoryInline:
            Text("\(w.word) — “\(w.lit)”")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(w.word).font(.serif(17, .bold)).widgetAccentable()
                Text("“\(w.lit)”").font(.serif(13, .regular)).italic().lineLimit(2)
                Text(w.origin).font(.ui(11, .semibold)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        #endif
        case .systemSmall:
            small(w)
        case .systemMedium:
            medium(w)
        default:
            large(w)
        }
    }

    private func label() -> some View {
        Text("WORD OF THE DAY")
            .font(.ui(9.5, .heavy)).tracking(1.2)
            .foregroundStyle(Palette.ember)
    }

    private func small(_ w: Word) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            label()
            Spacer(minLength: 4)
            Text(w.word)
                .font(.serif(28, .black))
                .foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.45)
            Text("“\(w.lit)”")
                .font(.serif(14, .semibold)).italic()
                .foregroundStyle(Palette.ember)
                .lineLimit(2).minimumScaleFactor(0.8)
                .padding(.top, 2)
            Spacer(minLength: 4)
            HStack(spacing: 5) {
                LanguageDot(language: w.origin, size: 7)
                Text(w.origin).font(.ui(11, .bold)).foregroundStyle(Palette.language(w.origin))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func medium(_ w: Word) -> some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                label()
                Text(w.word)
                    .font(.serif(30, .black))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.top, 4)
                Text(w.def)
                    .font(.ui(12.5, .medium))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(2)
                Spacer(minLength: 4)
                Text("literally").font(.serif(11, .regular)).italic().foregroundStyle(Palette.inkSoft)
                Text("“\(w.lit)”")
                    .font(.serif(16, .semibold)).italic()
                    .foregroundStyle(Palette.ember)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            Image("digby_read")
                .resizable()
                .widgetAccentedRenderingMode(.desaturated)
                .scaledToFit()
                .frame(width: 104)
        }
    }

    private func large(_ w: Word) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    label()
                    Text(w.word)
                        .font(.serif(36, .black))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Text("\(w.pron) · \(w.pos)").font(.ui(12, .medium)).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                Image("digby_read").resizable().widgetAccentedRenderingMode(.desaturated).scaledToFit().frame(width: 84)
            }
            Text("“\(w.lit)”")
                .font(.serif(19, .semibold)).italic()
                .foregroundStyle(Palette.ember)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(w.journey.reversed().prefix(4).enumerated()), id: \.offset) { _, step in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        LanguageDot(language: step.lang, size: 7)
                        Text(step.lang).font(.ui(11, .heavy)).foregroundStyle(Palette.language(step.lang))
                            .frame(width: 92, alignment: .leading)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text(step.form).font(.serif(14, .semibold)).italic().foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.top, 14)
            Spacer(minLength: 8)
            Text(w.story)
                .font(.serif(13, .regular))
                .foregroundStyle(Palette.ink)
                .lineLimit(4)
        }
    }
}

// MARK: - Streak

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Streak", provider: RootleProvider()) { entry in
            StreakView(entry: entry)
                .containerBackground(for: .widget) { Palette.paper }
                .widgetURL(URL(string: "rootle://grove"))
        }
        .configurationDisplayName("Streak Plant")
        .description("Water your roots: watch your streak grow.")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .accessoryCircular])
        #else
        .supportedFamilies([.systemSmall])
        #endif
    }
}

struct StreakView: View {
    let entry: RootleEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryCircular:
            Gauge(value: Double(min(entry.xpToday, entry.goal)), in: 0...Double(max(entry.goal, 1))) {
                Image(systemName: "leaf.fill")
            } currentValueLabel: {
                Text("\(entry.streak)").font(.ui(18, .heavy))
            }
            .gaugeStyle(.accessoryCircular)
        #endif
        default:
            VStack(spacing: 0) {
                Image(entry.stage == 0 ? "scene_dormant" : "grow_\(entry.stage)")
                    .resizable()
                    .widgetAccentedRenderingMode(.desaturated)
                    .scaledToFit()
                    .frame(maxHeight: 82)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.streak)")
                        .font(.serif(28, .black))
                        .foregroundStyle(Palette.ink)
                    Text(entry.streak == 1 ? "day" : "days")
                        .font(.ui(13, .bold))
                        .foregroundStyle(Palette.inkSoft)
                }
                Text(entry.watered ? "Watered today" : "Needs water")
                    .font(.ui(11.5, .heavy))
                    .foregroundStyle(entry.watered ? Palette.moss : Palette.ember)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
