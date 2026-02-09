import SwiftUI
import ComposableArchitecture

struct ClipboardHistoryView: View {
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

                    // PiP状態の表示
                    HStack {
                        Circle()
                            .fill(store.isPiPActive ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)

                        Text(store.isPiPActive ? "PiPモード: アクティブ" : "PiPモード: 停止中")
                            .font(.caption)
                            .foregroundColor(store.isPiPActive ? .green : .secondary)

                        Spacer()

                        if store.isPiPActive {
                            Text("バックグラウンドで監視中")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.vertical, 8)
            } header: {
                Text("バックグラウンド監視")
            } footer: {
                Text("ビデオをPiPモードにすると、他のアプリを使用中もクリップボードを監視できます。")
                    .font(.caption2)
            }

            ForEach(store.items) { item in
                ClipboardItemRow(item: item)
                    .onTapGesture {
                        if item.type == .image {
                            store.send(.showImagePreview(item))
                        } else {
                            store.send(.pasteItem(item))
                        }
                    }
            }
            .onDelete { indexSet in
                store.send(.removeItems(indexSet))
            }
        }
        .navigationTitle("Clipboard History")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                #if DEBUG
                NavigationLink(destination: ScreenshotPreviewView()) {
                    Image(systemName: "camera.fill")
                }
                #endif

                // 監視状態の表示
                HStack(spacing: 4) {
                    Circle()
                        .fill(store.isMonitoring ? Color.blue : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(store.isMonitoring ? "監視中" : "停止")
                        .font(.caption)
                        .foregroundColor(store.isMonitoring ? .blue : .gray)
                }

                Button(store.isMonitoring ? "Stop" : "Start") {
                    store.send(store.isMonitoring ? .stopMonitoring : .startMonitoring)
                }
                .tint(store.isMonitoring ? .red : .blue)

                Button("Clear") {
                    store.send(.clearAll)
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
            // 監視を自動開始
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

            PiPモードを使用することで、バックグラウンドでも監視を継続できます。
            """)
        }
        .sheet(
            isPresented: Binding(
                get: { store.selectedImageItem != nil },
                set: { if !$0 { store.send(.dismissImagePreview) } }
            )
        ) {
            if let imageItem = store.selectedImageItem {
                ImagePreviewView(item: imageItem)
            }
        }
    }
} 