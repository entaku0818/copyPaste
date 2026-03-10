import SwiftUI
import StoreKit
import ComposableArchitecture

struct SettingsView: View {
    let store: StoreOf<ClipboardHistoryFeature>
    @State private var showOnboarding = false
    @State private var showPaywall = false
    @State private var showTrash = false
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
                    if store.isProUser {
                        Button {
                            showTrash = true
                        } label: {
                            Label("ゴミ箱", systemImage: "trash")
                        }
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
                } header: {
                    Text("デバッグ")
                } footer: {
                    Text("App Store用のスクリーンショットをプレビューできます")
                        .font(.caption)
                }
                #endif
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
