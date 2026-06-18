import SwiftUI
import StoreKit
import ComposableArchitecture
import GoogleMobileAds

struct SettingsView: View {
    let store: StoreOf<ClipboardHistoryFeature>
    @State private var showOnboarding = false
    @State private var showPaywall = false
    @State private var showTrash = false
    @State private var showExportPicker = false
    @State private var exportURL: URL?
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
                                Text("settings.proDescription")
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
                        Label("settings.howToUse", systemImage: "book.fill")
                    }
                    Button {
                        requestReview()
                    } label: {
                        Label("settings.writeReview", systemImage: "star.fill")
                    }
                    Button {
                        store.send(.satisfactionResponseNegative)
                    } label: {
                        Label("settings.contact", systemImage: "envelope")
                    }
                    if store.isProUser {
                        Button {
                            showTrash = true
                        } label: {
                            Label("settings.trash", systemImage: "trash")
                        }
                    }
                }

                // エクスポートセクション（Pro限定）
                if store.isProUser {
                    Section {
                        Button {
                            showExportPicker = true
                        } label: {
                            Label("export.action", systemImage: "square.and.arrow.up")
                        }
                    } header: {
                        Text("export.title")
                    }
                }

                // iCloud同期セクション（Pro限定）
                if store.isProUser {
                    Section {
                        Picker("settings.iCloudSyncPicker", selection: $syncMode) {
                            ForEach(CloudKitSyncMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .onChange(of: syncMode) { _, newMode in
                            CloudKitSyncMode.current = newMode
                        }
                    } header: {
                        Label("settings.iCloudSync", systemImage: "icloud")
                    } footer: {
                        Text("settings.iCloudSyncFooter")
                            .font(.caption2)
                    }
                }

                // アプリ情報セクション
                Section {
                    HStack {
                        Text("settings.version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }

                } header: {
                    Text("settings.appInfo")
                }

                // デバッグセクション（DEBUGビルドのみ）
                #if DEBUG
                Section {
                    NavigationLink(destination: ScreenshotPreviewView()) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Text("settings.screenshotPreview")
                        }
                    }
                    NavigationLink(destination: KeyboardLogView()) {
                        HStack {
                            Image(systemName: "keyboard")
                                .foregroundColor(.purple)
                                .frame(width: 30)
                            Text("settings.keyboardLog")
                        }
                    }
                } header: {
                    Text("settings.debug")
                } footer: {
                    Text("settings.keyboardLogFooter")
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
            .navigationTitle("settings.title")
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
            .sheet(item: $exportURL) { url in
                ShareSheet(url: url)
            }
            .confirmationDialog("export.formatPicker", isPresented: $showExportPicker, titleVisibility: .visible) {
                Button("CSV") {
                    exportURL = ExportManager.export(store.items, format: .csv)
                }
                Button("Markdown") {
                    exportURL = ExportManager.export(store.items, format: .markdown)
                }
                Button("button.cancel", role: .cancel) {}
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
