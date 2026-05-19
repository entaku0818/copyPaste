import SwiftUI
import StoreKit
import ComposableArchitecture
import GoogleMobileAds

struct SettingsView: View {
    let store: StoreOf<ClipboardHistoryFeature>
    @State private var showOnboarding = false
    @State private var showPaywall = false
    @State private var showTrash = false
    @State private var syncMode: CloudKitSyncMode = CloudKitSyncMode.current
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NavigationStack {
            List {
                // Pro アップグレードセクション
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ClipKit Pro")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("3ヶ月履歴・お気に入り・ウィジェット")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // 使い方セクション（オンボーディング再表示）
                Section {
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("使い方を見る", systemImage: "book.fill")
                    }
                    Button {
                        requestReview()
                    } label: {
                        Label("レビューを書く", systemImage: "star.fill")
                    }
                    Button {
                        store.send(.satisfactionResponseNegative)
                    } label: {
                        Label("お問い合わせ", systemImage: "envelope")
                    }
                    if store.isProUser {
                        Button {
                            showTrash = true
                        } label: {
                            Label("ゴミ箱", systemImage: "trash")
                        }
                    }
                }

                // iCloud同期セクション（Pro限定）
                if store.isProUser {
                    Section {
                        Picker("同期する内容", selection: $syncMode) {
                            ForEach(CloudKitSyncMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .onChange(of: syncMode) { _, newMode in
                            CloudKitSyncMode.current = newMode
                        }
                    } header: {
                        Label("iCloud同期", systemImage: "icloud")
                    } footer: {
                        Text("「画像・ファイルも含む全て」を選択するとiCloudストレージを消費します。")
                            .font(.caption2)
                    }
                }

                // アプリ情報セクション
                Section {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }

                } header: {
                    Text("アプリ情報")
                }

                // デバッグセクション（DEBUGビルドのみ）
                #if DEBUG
                Section {
                    NavigationLink(destination: ScreenshotPreviewView()) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Text("スクリーンショットプレビュー")
                        }
                    }
                    NavigationLink(destination: KeyboardLogView()) {
                        HStack {
                            Image(systemName: "keyboard")
                                .foregroundColor(.purple)
                                .frame(width: 30)
                            Text("キーボードログ")
                        }
                    }
                } header: {
                    Text("デバッグ")
                } footer: {
                    Text("キーボードログはApp Groups経由でリアルタイム収集されます")
                        .font(.caption)
                }
                #endif
            }
            .safeAreaInset(edge: .bottom) {
                if !store.isProUser {
                    BannerAdView()
                        .frame(height: BannerAdView.adaptiveHeight)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showOnboarding) {
                OnboardingView {
                    showOnboarding = false
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showTrash) {
                TrashView(store: store)
            }
        }
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

}

#Preview {
    SettingsView(store: Store(initialState: ClipboardHistoryFeature.State()) {
        ClipboardHistoryFeature()
    })
}
