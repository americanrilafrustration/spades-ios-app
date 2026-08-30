import SwiftUI

@main
struct SpadesApp: App {
    @StateObject private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
        }
    }
}

struct RootView: View {
    @ObservedObject var store: GameStore

    var body: some View {
        Group {
            switch store.state.phase {
            case .menu:
                MenuView(store: store)
            case .rules:
                RulesView(onBack: store.backToMenu)
            case .lobby:
                LobbyView(store: store)
            case .dealing, .bidding, .playing, .handOver, .gameOver:
                GameView(store: store)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.state.phase)
    }
}
