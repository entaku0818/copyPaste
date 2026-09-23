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
                Label("tab.monitoring", systemImage: "play.circle.fill")
            }
            .tag(0)

            NavigationStack {
                ClipboardHistoryView(store: store)
            }
            .tabItem {
                Label("tab.history", systemImage: "clock.fill")
            }
            .tag(1)

            NavigationStack {
                FavoritesView(store: store)
            }
            .tabItem {
                Label("tab.favorites", systemImage: "star.fill")
            }
            .tag(2)

            NavigationStack {
                SnippetsView(store: store)
            }
            .tabItem {
                Label("snippets.title", systemImage: "text.quote")
            }
            .tag(3)

            NavigationStack {
                SettingsView(store: store)
            }
            .tabItem {
                Label("tab.settings", systemImage: "gearshape.fill")
            }
            .tag(4)
        }
        .tint(ClipKitColor.indigo)
        .onChange(of: selectedTab) { _, _ in
            store.send(.tabChanged)
        }
        // レビュー事前確認は画面中央のモーダルで出す。
        //
        // fullScreenCover は presentation style が .fullScreen のため、
        // presentationBackground(.clear) にしても背面が描画されず画面全体が
        // 黒くなる（UIKitが presenting view を外すため）。
        // .overFullScreen 相当をSwiftUIから指定できないので、
        // TabViewの親であるここにoverlayとして重ねてタブバーごと覆う。
        .overlay {
            if store.showSatisfactionPrompt {
                SatisfactionPromptView(
                    onSatisfied: { store.send(.satisfactionResponsePositive) },
                    onUnsatisfied: { store.send(.satisfactionResponseNegative) }
                )
                // 「表示した」記録は実際に画面に出たここで行う（判定時ではない）
                .onAppear { store.send(.satisfactionPromptShown) }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.showSatisfactionPrompt)
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
