#if os(macOS)
import SwiftUI

/// The Mac window: a warm, illustrated sidebar instead of the system one.
struct MacShell: View {
    @Binding var section: RootView.Section

    var body: some View {
        HStack(spacing: 0) {
            MacSidebar(section: $section)
            Group {
                switch section {
                case .dig: HomeView()
                case .lexicon: LexiconView()
                case .grove: GroveView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.paper)
        }
        .background(Palette.paper.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .top)
    }
}

private struct MacSidebar: View {
    @Environment(GameStore.self) private var store
    @Binding var section: RootView.Section

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image("digby_wave").resizable().scaledToFit().frame(width: 46, height: 46)
                Text("Rootle")
                    .font(.serif(30, .black))
                    .foregroundStyle(Palette.ember)
            }
            .padding(.top, 50)
            .padding(.leading, 18)
            .accessibilityElement(children: .combine)

            VStack(spacing: 6) {
                item(.dig, "Dig Site", art: "digby_dig", tint: Palette.ember, key: "1")
                item(.lexicon, "Lexicon", art: "digby_read", tint: Palette.teal, key: "2")
                item(.grove, "Grove", art: "grow_3", tint: Palette.moss, key: "3")
            }
            .padding(.top, 30)
            .padding(.horizontal, 12)

            Spacer(minLength: 20)

            if section != .grove {
                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
                    .transition(.opacity)
            }
        }
        .frame(width: 228)
        .frame(maxHeight: .infinity)
        .background(Palette.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(Palette.line).frame(width: 1.5) }
    }

    private func item(_ s: RootView.Section, _ title: String, art: String, tint: Color, key: KeyEquivalent) -> some View {
        let selected = section == s
        return Button { section = s } label: {
            HStack(spacing: 12) {
                Image(art).resizable().scaledToFit().frame(width: 38, height: 38)
                Text(title.uppercased())
                    .font(.ui(14, .heavy)).tracking(1.1)
                    .foregroundStyle(selected ? tint : Palette.inkSoft)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? tint.opacity(0.13) : .clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? tint.opacity(0.55) : .clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(SidebarPress())
        .keyboardShortcut(key, modifiers: .command)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Streak plant and today's goal, always in view.
    private var footer: some View {
        let stage = store.state.growthStage()
        let watered = store.state.activeToday()
        return VStack(alignment: .leading, spacing: 10) {
            Image(stage == 0 ? "scene_dormant" : "grow_\(stage)")
                .resizable().scaledToFit()
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(store.streak)")
                    .font(.serif(30, .black))
                    .foregroundStyle(Palette.ink)
                Text(store.streak == 1 ? "day streak" : "day streak")
                    .font(.ui(13, .bold))
                    .foregroundStyle(Palette.inkSoft)
            }
            Text(watered ? "Watered today" : "Needs water today")
                .font(.ui(12, .heavy))
                .foregroundStyle(watered ? Palette.moss : Palette.ember)
            VStack(alignment: .leading, spacing: 6) {
                ThickProgressBar(value: store.goalProgress, fill: Palette.ochre, height: 12)
                    .frame(height: 12)
                Text("\(store.xpToday) / \(store.state.dailyGoal) XP today")
                    .font(.ui(12, .bold)).monospacedDigit()
                    .foregroundStyle(Palette.inkSoft)
            }
            .padding(.top, 4)
        }
    }
}

private struct SidebarPress: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.ink.opacity(hovering ? 0.05 : 0)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
            .onHover { hovering = $0 }
    }
}

#if DEBUG
/// Debug hooks, run from a terminal so output lands on stdout (the app is sandboxed):
/// `-snapshot` renders each section in light and dark and prints them as base64 PNGs, then quits.
/// `-forgeTest` digs one real layer with Claude, prints it, then quits.
enum Snapshotter {
    @MainActor
    static func runIfRequested(section: Binding<RootView.Section>, store: GameStore) async {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-forgeTest") {
            await store.digNewLayer()
            if let err = store.digError { print("FORGE-ERROR \(err)") }
            if let unit = store.lexicon.units.last {
                print("FORGE-LAYER \(unit.title) — \(unit.subtitle) [\(unit.emblem)]")
                for id in unit.words { if let w = store.lexicon.word(id) { print("FORGE-WORD \(w.word) | \(w.lit) | \(w.origin) | journey \(w.journey.count) | parts \(w.parts.count) | myth \(w.myth != nil)") } }
            }
            print("FORGE-TOTAL \(store.lexicon.ordered.count)")
            fflush(stdout)
            exit(0)
        }
        guard args.contains("-snapshot") else { return }
        try? await Task.sleep(for: .seconds(1.5))
        guard let window = NSApp.windows.first(where: { $0.isVisible }) else { exit(1) }
        let widths: [CGFloat] = args.contains("-snapshotNarrow") ? [1120, 820] : [1120]
        for (name, look) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            NSApp.appearance = NSAppearance(named: look)
            for w in widths {
                window.setContentSize(NSSize(width: w, height: 820))
                for (sName, s) in [("dig", RootView.Section.dig), ("lexicon", .lexicon), ("grove", .grove)] {
                    section.wrappedValue = s
                    try? await Task.sleep(for: .seconds(1.2))
                    capture(window, name: "\(sName)-\(name)-\(Int(w))")
                }
            }
        }
        fflush(stdout)
        exit(0)
    }

    @MainActor
    private static func capture(_ window: NSWindow, name: String) {
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        print("SNAP \(name) \(png.base64EncodedString())")
    }
}
#endif
#endif
