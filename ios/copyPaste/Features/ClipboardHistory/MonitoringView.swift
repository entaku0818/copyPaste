import SwiftUI
import ComposableArchitecture

struct MonitoringView: View {
    let store: StoreOf<ClipboardHistoryFeature>

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    VideoPlayerView { isActive in
                        store.send(.pipStateChanged(isActive))
                    }
                    .frame(height: 100)
                    .cornerRadius(8)

                    HStack {
                        Circle()
                            .fill(store.isPiPActive ? Color.green : Color.blue)
                            .frame(width: 8, height: 8)
                        Text(store.isPiPActive ? "バックグラウンドで監視中" : "監視中")
                            .font(.caption)
                            .foregroundColor(store.isPiPActive ? .green : .blue)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.vertical, 8)
            } header: {
                Text("バックグラウンド監視")
            } footer: {
                Text("このアプリを起動した状態でバックグラウンドにすると、他のアプリを使用中もクリップボードを監視できます。")
                    .font(.caption2)
            }

            Section {
                HStack {
                    Circle()
                        .fill(store.isMonitoring ? Color.blue : Color.gray)
                        .frame(width: 10, height: 10)

                    Text(store.isMonitoring ? "監視中" : "停止中")
                        .font(.subheadline)
                        .foregroundColor(store.isMonitoring ? .blue : .secondary)

                    Spacer()

                    Button(store.isMonitoring ? "Stop" : "Start") {
                        store.send(store.isMonitoring ? .stopMonitoring : .startMonitoring)
                    }
                    .tint(store.isMonitoring ? .red : .blue)
                }
                .padding(.vertical, 4)
            } header: {
                Text("監視コントロール")
            }
        }
        .navigationTitle("常時起動")
        .onAppear {
            store.send(.onAppear)
            store.send(.startMonitoring)
        }
        .alert(
            "クリップボードアクセス許可",
            isPresented: Binding(
                get: { store.showPermissionAlert },
                set: { if !$0 { store.send(.dismissPermissionAlert) } }
            )
        ) {
            Button("許可する") {
                store.send(.requestClipboardPermission)
            }
            Button("後で", role: .cancel) {
                store.send(.dismissPermissionAlert)
            }
        } message: {
            Text("""
            このアプリはクリップボードの履歴を保存するため、クリップボードへのアクセスが必要です。

            iOS 16以降では、初回アクセス時にシステムの確認が表示されます。「許可」を選択してください。
            """)
        }
    }
}
