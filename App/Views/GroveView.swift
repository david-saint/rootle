import SwiftUI

/// Profile: your streak plant, stats, week, badges and settings.
struct GroveView: View {
    @Environment(GameStore.self) private var store
    @State private var confirmReset = false
    @State private var pickingFolder = false

    var body: some View {
        let s = store.state
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    plant
                    stats(s).padding(.top, 34)
                    week.padding(.top, 44)
                    badges.padding(.top, 44)
                    settings(s).padding(.top, 44)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .pageWidth(680)
            }
            .background(Palette.paper)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) { store.resetProgress() }
        } message: {
            Text("Your streak, XP and lexicon will be cleared. This can't be undone.")
        }
    }

    private var plant: some View {
        let stage = store.state.growthStage()
        let streak = store.streak
        let watered = store.state.activeToday()
        return VStack(spacing: 4) {
            Image(stage == 0 ? "scene_dormant" : "grow_\(stage)")
                .resizable().scaledToFit()
                .frame(maxWidth: 300)
                .accessibilityHidden(true)
            Text(streak == 0 ? "Plant a streak" : "\(streak)-day streak")
                .font(.serif(38, .black))
                .foregroundStyle(Palette.ink)
            Text(watered ? "Watered today. See you tomorrow!"
                 : streak > 0 ? "Finish a lesson today to keep it growing."
                 : "Finish a lesson to sprout your first seed.")
                .font(.ui(16, .medium))
                .foregroundStyle(watered ? Palette.moss : Palette.inkSoft)
                .multilineTextAlignment(.center)
            if stage < 5 {
                Text(nextStageHint(streak))
                    .font(.serif(14, .regular)).italic()
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func nextStageHint(_ streak: Int) -> String {
        let next = [1, 3, 7, 14, 30].first { $0 > streak } ?? 30
        let d = next - streak
        return "\(d) more day\(d == 1 ? "" : "s") to the next growth stage"
    }

    private func stats(_ s: ProgressState) -> some View {
        HStack(spacing: 0) {
            stat("\(s.xp)", "Total XP")
            stat("\(s.words.count)", "Words")
            stat("\(s.longestStreak)", "Best streak")
            stat("\(s.lessonsDone)", "Lessons")
        }
        .padding(.vertical, 18)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1.5) }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.serif(30, .black)).foregroundStyle(Palette.ink).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.ui(13, .semibold)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    private var week: some View {
        let days = store.week
        let goal = store.state.dailyGoal
        let top = max(goal, days.map(\.xp).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(.serif(24, .bold)).foregroundStyle(Palette.ink)
                Spacer()
                Text("Goal \(goal) XP a day").font(.ui(13, .semibold)).foregroundStyle(Palette.inkSoft)
            }
            ZStack(alignment: .bottom) {
                GeometryReader { geo in
                    let y = geo.size.height * (1 - CGFloat(goal) / CGFloat(top))
                    Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y)) }
                        .stroke(Palette.ochre, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                        VStack(spacing: 8) {
                            if d.xp > 0 {
                                Text("\(d.xp)").font(.ui(11, .bold)).foregroundStyle(Palette.inkSoft).monospacedDigit()
                            }
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(d.xp >= goal ? Palette.moss : d.xp > 0 ? Palette.ochre : Palette.line)
                                .frame(height: max(6, 120 * CGFloat(d.xp) / CGFloat(top)))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 150)
            HStack(spacing: 12) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                    Text(d.label)
                        .font(.ui(12, d.isToday ? .heavy : .semibold))
                        .foregroundStyle(d.isToday ? Palette.ember : Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var badges: some View {
        VStack(alignment: .leading, spacing: 18) {
            let list = store.badges
            HStack(alignment: .firstTextBaseline) {
                Text("Finds").font(.serif(24, .bold)).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(list.filter(\.earned).count) of \(list.count)").font(.ui(13, .semibold)).foregroundStyle(Palette.inkSoft)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 22) {
                ForEach(list) { b in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(b.earned ? Palette.ochreShade : Palette.line).offset(y: 4)
                            Circle().fill(b.earned ? Palette.ochre : Palette.sunk)
                                .overlay(Circle().strokeBorder(b.earned ? Palette.ochreShade.opacity(0.4) : Palette.line, lineWidth: 2))
                            Image(systemName: b.symbol)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(b.earned ? .white : Palette.inkSoft.opacity(0.45))
                        }
                        .frame(width: 66, height: 66)
                        Text(b.title).font(.ui(13.5, .bold))
                            .foregroundStyle(b.earned ? Palette.ink : Palette.inkSoft)
                        Text(b.detail).font(.ui(11.5, .medium)).foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(b.title), \(b.detail), \(b.earned ? "earned" : "not yet earned")")
                }
            }
        }
    }

    private func settings(_ s: ProgressState) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings").font(.serif(24, .bold)).foregroundStyle(Palette.ink)

            VStack(alignment: .leading, spacing: 10) {
                Text("Daily goal").font(.ui(15, .bold)).foregroundStyle(Palette.ink)
                Picker("Daily goal", selection: Binding(get: { s.dailyGoal }, set: { store.setDailyGoal($0) })) {
                    Text("Casual · 10").tag(10)
                    Text("Regular · 20").tag(20)
                    Text("Serious · 30").tag(30)
                    Text("Intense · 50").tag(50)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily word reminder").font(.ui(15, .bold)).foregroundStyle(Palette.ink)
                    Text("A nudge with that day's word.").font(.ui(13, .medium)).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                if s.reminderEnabled {
                    Picker("Time", selection: Binding(get: { s.reminderHour }, set: { store.setReminder(enabled: true, hour: $0) })) {
                        ForEach([7, 8, 9, 12, 17, 18, 19, 20, 21], id: \.self) { h in
                            Text(hourLabel(h)).tag(h)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Toggle("Daily word reminder", isOn: Binding(get: { s.reminderEnabled }, set: { store.setReminder(enabled: $0, hour: s.reminderHour) }))
                    .labelsHidden()
                    .tint(Palette.moss)
            }

            syncRow

            Button("Reset progress…", role: .destructive) { confirmReset = true }
                .buttonStyle(.plain)
                .font(.ui(14, .semibold))
                .foregroundStyle(Palette.ember)
                .padding(.top, 6)
        }
    }

    private var syncRow: some View {
        let sync = CloudSync.shared
        let (symbol, tint, detail): (String, Color, String) = {
            switch sync.status {
            case .notSetUp:
                return ("icloud", Palette.inkSoft, "Pick a folder in iCloud Drive (for example a new one called Rootle). Choose the same folder on your other devices and they'll share progress and words.")
            case .syncing:
                return ("arrow.triangle.2.circlepath.icloud", Palette.teal, "Syncing with \(sync.folderName ?? "iCloud Drive")…")
            case .synced(let d):
                return ("checkmark.icloud.fill", Palette.moss, "\(sync.folderName ?? "Folder") · up to date \(d.formatted(.relative(presentation: .named)))")
            case .waiting(let n):
                return ("icloud.and.arrow.down", Palette.teal, "Downloading \(n) file\(n == 1 ? "" : "s") from your other devices…")
            case .failed(let m):
                return ("exclamationmark.icloud", Palette.ember, m)
            }
        }()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sync with iCloud Drive").font(.ui(15, .bold)).foregroundStyle(Palette.ink)
                    Text(detail).font(.ui(13, .medium)).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if !sync.inICloudDrive {
                        Text("That folder isn't in iCloud Drive, so it won't reach your other devices.")
                            .font(.ui(13, .semibold)).foregroundStyle(Palette.ember)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 18) {
                if sync.status == .notSetUp {
                    Button("Choose folder…") { pickingFolder = true }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, shade: Palette.tealShade, height: 42))
                        .frame(maxWidth: 220)
                } else {
                    Button("Sync now") { Task { await sync.syncNow() } }
                        .disabled(sync.status == .syncing)
                    Button("Change folder…") { pickingFolder = true }
                    Button("Stop syncing", role: .destructive) { sync.disconnect() }
                        .foregroundStyle(Palette.ember)
                }
            }
            .buttonStyle(.plain)
            .font(.ui(14, .bold))
            .foregroundStyle(Palette.teal)
            .padding(.leading, 42)
        }
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { sync.connect(url) }
        }
    }

    private func hourLabel(_ h: Int) -> String {
        var c = DateComponents(); c.hour = h
        let d = Calendar.current.date(from: c) ?? .now
        return d.formatted(date: .omitted, time: .shortened)
    }
}
