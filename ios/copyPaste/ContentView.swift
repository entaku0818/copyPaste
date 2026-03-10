import SwiftUI
import ComposableArchitecture

public struct ContentView: View {
    let store: StoreOf<ClipboardHistoryFeature>
    @State private var selectedTab = 1

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MonitoringView(store: store)
            }
            .tabItem {
                Label("常時起動", systemImage: "play.circle.fill")
            }
            .tag(0)

            NavigationStack {
                ClipboardHistoryView(store: store)
            }
            .tabItem {
                Label("履歴", systemImage: "clock.fill")
            }
            .tag(1)

            NavigationStack {
                FavoritesView(store: store)
            }
            .tabItem {
                Label("お気に入り", systemImage: "star.fill")
            }
            .tag(2)

            NavigationStack {
                SettingsView(store: store)
            }
            .tabItem {
                Label("設定", systemImage: "gearshape.fill")
            }
            .tag(3)
        }
    }
}

#Preview {
    ContentView(
        store: Store(
            initialState: ClipboardHistoryFeature.State()
        ) {
            ClipboardHistoryFeature()
        }
    )
} 
