import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // アプリ情報セクション
                Section {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("ビルド")
                        Spacer()
                        Text(buildNumber)
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

                // その他セクション
                Section {
                    Link(destination: URL(string: "https://github.com/entaku0818/copyPaste")!) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Text("GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("リンク")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

#Preview {
    SettingsView()
}
