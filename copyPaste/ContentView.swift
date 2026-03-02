import SwiftUI
import ComposableArchitecture

public struct ContentView: View {
    let store: StoreOf<ClipboardHistoryFeature>

    public var body: some View {
        TabView {
            NavigationStack {
                MonitoringView(store: store)
            }
            .tabItem {
                Label("常時起動", systemImage: "play.circle.fill")
            }

            NavigationStack {
                ClipboardHistoryView(store: store)
            }
            .tabItem {
                Label("履歴", systemImage: "clock.fill")
            }
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
