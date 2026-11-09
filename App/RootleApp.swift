import SwiftUI
@main
struct RootleApp: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                #if os(macOS)
                .frame(minWidth: 760, minHeight: 640)
                #endif
                .onAppear {
                    Reminders.reschedule(enabled: store.state.reminderEnabled, hour: store.state.reminderHour)
                    CloudSync.shared.start(store: store)
                }
        }
        #if os(macOS)
        .defaultSize(width: 1120, height: 820)
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        #endif
    }
}

struct RootView: View {
    enum Section: Hashable { case dig, lexicon, grove }

    @Environment(GameStore.self) private var store
    @State private var section: Section = .dig
    @State private var linkedWord: Word?
    @Environment(\.scenePhase) private var phase

    var body: some View {
        content
            .onOpenURL { url in
                // rootle://word/<id>
                guard url.scheme == "rootle" else { return }
                if url.host == "word", let id = url.pathComponents.last, let w = store.lexicon.word(id) {
                    section = .dig
                    linkedWord = w
                } else if url.host == "grove" {
                    section = .grove
                }
            }
            .sheet(item: $linkedWord) { w in
                WordDetailView(word: w, isWordOfTheDay: w.id == store.wordOfTheDay.id)
            }
            .onChange(of: phase) { _, now in
                guard now == .active else { return }
                store.pinToday()
                Task {
                    await CloudSync.shared.syncNow()
                    await store.keepRunway()
                }
            }
            .alert("Digging hit a rock", isPresented: Binding(get: { store.digError != nil }, set: { if !$0 { store.digError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.digError ?? "")
            }
            #if os(macOS) && DEBUG
            .task { await Snapshotter.runIfRequested(section: $section, store: store) }
            #endif
    }

    @ViewBuilder private var content: some View {
        #if os(macOS)
        MacShell(section: $section)
        #else
        TabView(selection: $section) {
            Tab("Dig Site", systemImage: "map.fill", value: Section.dig) {
                HomeView()
            }
            Tab("Lexicon", systemImage: "books.vertical.fill", value: Section.lexicon) {
                LexiconView()
            }
            Tab("Grove", systemImage: "leaf.fill", value: Section.grove) {
                GroveView()
            }
        }
        .tint(Palette.ember)
        #endif
    }
}
