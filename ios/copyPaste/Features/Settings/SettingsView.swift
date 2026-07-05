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
            ScrollView {
                VStack(alignment: .leading, spacing: ClipKitSpacing.sectionGap) {
                    // Pro ヒーローカード（ダークサーフェス）
                    Button {
                        showPaywall = true
                    } label: {
                        DarkHeroCard {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: ClipKitRadius.badge + 1, style: .continuous)
                                        .fill(ClipKitColor.brandGradient)
                                        .frame(width: 46, height: 46)
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(ClipKitColor.crown)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ClipKit Pro")
                                        .font(.system(size: 17, weight: .heavy))
                                        .foregroundColor(ClipKitColor.textOnDark)
                                    Text("settings.proDescription")
                                        .font(.system(size: 12))
                                        .foregroundColor(ClipKitColor.textOnDarkSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(ClipKitColor.textOnDarkSecondary)
                            }
                            .padding(18)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, ClipKitSpacing.screenPadding)

                    // 使い方セクション（オンボーディング再表示）
                    CardGroup {
                        settingsRow(icon: "book.fill", iconColor: ClipKitColor.indigo, title: "settings.howToUse") {
                            showOnboarding = true
                        }
                        CardDivider(leadingInset: 56)
                        settingsRow(icon: "star.fill", iconColor: ClipKitColor.favorite, title: "settings.writeReview") {
                            requestReview()
                        }
                        CardDivider(leadingInset: 56)
                        settingsRow(icon: "envelope.fill", iconColor: Color(hex: 0x7B5BD6), title: "settings.contact") {
                            store.send(.satisfactionResponseNegative)
                        }
                        if store.isProUser {
                            CardDivider(leadingInset: 56)
                            settingsRow(icon: "trash.fill", iconColor: ClipKitColor.textSecondary, title: "settings.trash") {
                                showTrash = true
                            }
                        }
                    }
                    .padding(.horizontal, ClipKitSpacing.screenPadding)

                    // エクスポート・iCloud同期セクション（Pro限定）
                    if store.isProUser {
                        CardGroup {
                            settingsRow(icon: "square.and.arrow.up", iconColor: ClipKitColor.textSecondary, title: "export.action") {
                                showExportPicker = true
                            }
                            CardDivider(leadingInset: 56)
                            HStack {
                                IconBadge(systemImage: "icloud.fill", colors: ClipKitColor.BadgeColors(background: Color(hex: 0x3AA3FF), foreground: .white), size: 29)
                                Text("settings.iCloudSync")
                                    .font(ClipKitFont.rowTitle)
                                    .foregroundColor(ClipKitColor.textPrimary)
                                    .padding(.leading, 12)
                                Spacer()
                                Picker("settings.iCloudSyncPicker", selection: $syncMode) {
                                    ForEach(CloudKitSyncMode.allCases, id: \.self) { mode in
                                        Text(mode.displayName).tag(mode)
                                    }
                                }
                                .tint(ClipKitColor.textTertiary)
                                .onChange(of: syncMode) { _, newMode in
                                    CloudKitSyncMode.current = newMode
                                }
                            }
                            .padding(.horizontal, ClipKitSpacing.cardPadding)
                            .padding(.vertical, ClipKitSpacing.rowVerticalPadding)
                        }
                        .padding(.horizontal, ClipKitSpacing.screenPadding)

                        Text("settings.iCloudSyncFooter")
                            .font(.caption2)
                            .foregroundColor(ClipKitColor.textTertiary)
                            .padding(.horizontal, ClipKitSpacing.screenPadding + ClipKitSpacing.cardPadding)
                    }

                    // アプリ情報セクション
                    VStack(alignment: .leading, spacing: 8) {
                        SectionCaptionLabel(title: String(localized: "settings.appInfo"))
                        CardGroup {
                            HStack {
                                Text("settings.version")
                                    .font(ClipKitFont.rowTitle)
                                    .foregroundColor(ClipKitColor.textPrimary)
                                Spacer()
                                Text(appVersion)
                                    .font(ClipKitFont.meta)
                                    .foregroundColor(ClipKitColor.textTertiary)
                            }
                            .padding(.horizontal, ClipKitSpacing.cardPadding)
                            .padding(.vertical, ClipKitSpacing.rowVerticalPadding)
                        }
                    }
                    .padding(.horizontal, ClipKitSpacing.screenPadding)

                    // デバッグセクション（DEBUGビルドのみ）
                    #if DEBUG
                    VStack(alignment: .leading, spacing: 8) {
                        SectionCaptionLabel(title: String(localized: "settings.debug"))
                        CardGroup {
                            NavigationLink(destination: ScreenshotPreviewView()) {
                                HStack {
                                    IconBadge(systemImage: "camera.fill", colors: ClipKitColor.BadgeColors(background: ClipKitColor.badgeBlue.foreground, foreground: .white), size: 29)
                                    Text("settings.screenshotPreview")
                                        .font(ClipKitFont.rowTitle)
                                        .foregroundColor(ClipKitColor.textPrimary)
                                        .padding(.leading, 12)
                                    Spacer()
                                }
                                .padding(.horizontal, ClipKitSpacing.cardPadding)
                                .padding(.vertical, ClipKitSpacing.rowVerticalPadding)
                            }
                            CardDivider(leadingInset: 56)
                            NavigationLink(destination: KeyboardLogView()) {
                                HStack {
                                    IconBadge(systemImage: "keyboard", colors: ClipKitColor.BadgeColors(background: ClipKitColor.badgePurple.foreground, foreground: .white), size: 29)
                                    Text("settings.keyboardLog")
                                        .font(ClipKitFont.rowTitle)
                                        .foregroundColor(ClipKitColor.textPrimary)
                                        .padding(.leading, 12)
                                    Spacer()
                                }
                                .padding(.horizontal, ClipKitSpacing.cardPadding)
                                .padding(.vertical, ClipKitSpacing.rowVerticalPadding)
                            }
                        }
                        Text("settings.keyboardLogFooter")
                            .font(.caption)
                            .foregroundColor(ClipKitColor.textTertiary)
                            .padding(.horizontal, ClipKitSpacing.cardPadding)
                    }
                    .padding(.horizontal, ClipKitSpacing.screenPadding)
                    #endif
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(ClipKitColor.canvas)
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

    // MARK: - Row Builder

    @ViewBuilder
    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                IconBadge(systemImage: icon, colors: ClipKitColor.BadgeColors(background: iconColor, foreground: .white), size: 29)
                Text(title)
                    .font(ClipKitFont.rowTitle)
                    .foregroundColor(ClipKitColor.textPrimary)
                    .padding(.leading, 12)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ClipKitColor.textTertiary)
            }
            .padding(.horizontal, ClipKitSpacing.cardPadding)
            .padding(.vertical, ClipKitSpacing.rowVerticalPadding)
        }
        .buttonStyle(.plain)
    }

}

#Preview {
    SettingsView(store: Store(initialState: ClipboardHistoryFeature.State()) {
        ClipboardHistoryFeature()
    })
}
