import SwiftUI

#if DEBUG
// MARK: - Screenshot Preview Feature
struct ScreenshotPreviewView: View {
    @State private var selectedLanguage: AppLanguage?

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Button(action: {
                        selectedLanguage = language
                    }) {
                        HStack {
                            Text(language.displayName)
                                .font(.headline)
                            Spacer()
                            Text(language.appTitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $selectedLanguage) { language in
                FullscreenScreenshotView(language: language, onDismiss: {
                    selectedLanguage = nil
                })
            }
        }
    }
}

// MARK: - Fullscreen Screenshot View
struct FullscreenScreenshotView: View {
    let language: AppLanguage
    let onDismiss: () -> Void
    @State private var selectedTab = 0
    @State private var dragOffset: CGSize = .zero

    private var isLastTab: Bool {
        selectedTab == ScreenshotScreen.allCases.count - 1
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Array(ScreenshotScreen.allCases.enumerated()), id: \.element) { index, screen in
                screenPreview(for: screen)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: [])
        .offset(x: isLastTab ? dragOffset.width : 0, y: dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = CGSize(width: 0, height: value.translation.height)
                    } else if isLastTab && value.translation.width > 0 {
                        dragOffset = CGSize(width: value.translation.width, height: 0)
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        onDismiss()
                    } else if isLastTab && value.translation.width > 150 {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private func screenPreview(for screen: ScreenshotScreen) -> some View {
        AppStoreScreenshotView(
            caption: screen.caption(language: language),
            background: screen.screenshotBackground
        ) {
            phoneContent(for: screen)
        }
    }

    @ViewBuilder
    private func phoneContent(for screen: ScreenshotScreen) -> some View {
        switch screen {
        case .clipboardHistory: MockClipboardHistoryView(language: language)
        case .keyboardPreview:  MockKeyboardPreviewView(language: language)
        case .pipMonitoring:    MockPiPMonitoringView(language: language)
        case .settings:         MockSettingsView(language: language)
        case .imagePreview:     MockImagePreviewView(language: language)
        case .keyboardSetup:    MockKeyboardSetupView(language: language)
        case .favorites:        MockFavoritesView(language: language)
        case .widget:           MockWidgetHomeContent(language: language)
        }
    }
}

// MARK: - Language Enum
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }

    var appTitle: String {
        switch self {
        case .english: return "Clipboard History"
        case .japanese: return "クリップボード履歴"
        }
    }

    var monitoring: String {
        switch self {
        case .english: return "Monitoring"
        case .japanese: return "監視中"
        }
    }

    var stopped: String {
        switch self {
        case .english: return "Stopped"
        case .japanese: return "停止"
        }
    }

    var startButton: String {
        switch self {
        case .english: return "Start"
        case .japanese: return "開始"
        }
    }

    var stopButton: String {
        switch self {
        case .english: return "Stop"
        case .japanese: return "停止"
        }
    }

    var backgroundMonitoring: String {
        switch self {
        case .english: return "Background Monitoring"
        case .japanese: return "バックグラウンド監視"
        }
    }

    var pipActive: String {
        switch self {
        case .english: return "PiP Mode: Active"
        case .japanese: return "PiPモード: アクティブ"
        }
    }

    var pipInactive: String {
        switch self {
        case .english: return "PiP Mode: Inactive"
        case .japanese: return "PiPモード: 停止中"
        }
    }

    var monitoringInBackground: String {
        switch self {
        case .english: return "Monitoring in background"
        case .japanese: return "バックグラウンドで監視中"
        }
    }

    var pipDescription: String {
        switch self {
        case .english: return "Enable PiP mode to monitor clipboard while using other apps."
        case .japanese: return "ビデオをPiPモードにすると、他のアプリを使用中もクリップボードを監視できます。"
        }
    }

    var keyboardExtension: String {
        switch self {
        case .english: return "Keyboard Extension"
        case .japanese: return "キーボード拡張"
        }
    }

    var keyboardDescription: String {
        switch self {
        case .english: return "Access clipboard history from any app using custom keyboard."
        case .japanese: return "カスタムキーボードを使用して、どのアプリからでもクリップボード履歴にアクセスできます。"
        }
    }

    var settings: String {
        switch self {
        case .english: return "Settings"
        case .japanese: return "設定"
        }
    }

    var appInfo: String {
        switch self {
        case .english: return "App Info"
        case .japanese: return "アプリ情報"
        }
    }

    var version: String {
        switch self {
        case .english: return "Version"
        case .japanese: return "バージョン"
        }
    }

    var build: String {
        switch self {
        case .english: return "Build"
        case .japanese: return "ビルド"
        }
    }

    var debug: String {
        switch self {
        case .english: return "Debug"
        case .japanese: return "デバッグ"
        }
    }

    var screenshotPreview: String {
        switch self {
        case .english: return "Screenshot Preview"
        case .japanese: return "スクリーンショットプレビュー"
        }
    }

    var imagePreviewTitle: String {
        switch self {
        case .english: return "Image Preview"
        case .japanese: return "画像プレビュー"
        }
    }

    var keyboardSetupTitle: String {
        switch self {
        case .english: return "Setup Keyboard"
        case .japanese: return "キーボード設定"
        }
    }

    var keyboardSetupStep1: String {
        switch self {
        case .english: return "1. Open Settings"
        case .japanese: return "1. 設定を開く"
        }
    }

    var keyboardSetupStep2: String {
        switch self {
        case .english: return "2. Go to General > Keyboard"
        case .japanese: return "2. 一般 > キーボードへ移動"
        }
    }

    var keyboardSetupStep3: String {
        switch self {
        case .english: return "3. Add New Keyboard"
        case .japanese: return "3. 新しいキーボードを追加"
        }
    }

    var keyboardSetupStep4: String {
        switch self {
        case .english: return "4. Enable Full Access"
        case .japanese: return "4. フルアクセスを許可"
        }
    }

    var done: String {
        switch self {
        case .english: return "Done"
        case .japanese: return "完了"
        }
    }

    var historyTitle: String {
        switch self {
        case .english: return "History"
        case .japanese: return "履歴"
        }
    }

    var proUpgradeTitle: String {
        switch self {
        case .english: return "Upgrade to ClipKit Pro"
        case .japanese: return "ClipKit Proにアップグレード"
        }
    }

    var proUpgradeDescription: String {
        switch self {
        case .english: return "Browse history older than 3 days"
        case .japanese: return "3日以上前の履歴も検索・閲覧できます"
        }
    }

    var searchPrompt: String {
        switch self {
        case .english: return "Search history..."
        case .japanese: return "履歴を検索..."
        }
    }

    func sampleText(_ index: Int) -> String {
        switch self {
        case .english:
            return [
                "Hello World! This is a sample text for clipboard testing.",
                "https://www.apple.com",
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                "Important: Meeting at 3 PM tomorrow",
                "Quick note: Buy groceries",
                "Sample email: user@example.com",
                "Phone: +1 (555) 123-4567",
                "Code snippet: func test() { print(\"Hello\") }",
                "https://github.com/entaku0818/copyPaste",
                "Remember to call back later"
            ][index % 10]
        case .japanese:
            return [
                "こんにちは世界！これはクリップボードテスト用のサンプルテキストです。",
                "https://www.apple.com/jp/",
                "吾輩は猫である。名前はまだ無い。",
                "重要：明日の午後3時にミーティング",
                "メモ：買い物に行く",
                "メール例：user@example.com",
                "電話：090-1234-5678",
                "コード例：func test() { print(\"こんにちは\") }",
                "https://github.com/entaku0818/copyPaste",
                "後で電話をかけ直すこと"
            ][index % 10]
        }
    }

    func sampleTime(_ index: Int) -> String {
        let times = ["1 min ago", "5 min ago", "10 min ago", "30 min ago", "1 hour ago", "2 hours ago", "3 hours ago", "5 hours ago", "1 day ago", "2 days ago"]
        let timesJa = ["1分前", "5分前", "10分前", "30分前", "1時間前", "2時間前", "3時間前", "5時間前", "1日前", "2日前"]
        return self == .english ? times[index % 10] : timesJa[index % 10]
    }
}

// MARK: - Screenshot Screen Enum
enum ScreenshotScreen: String, CaseIterable {
    case clipboardHistory
    case keyboardPreview
    case pipMonitoring
    case settings
    case imagePreview
    case keyboardSetup
    case favorites
    case widget
}

// MARK: - ScreenshotScreen captions & backgrounds
extension ScreenshotScreen {
    func caption(language: AppLanguage) -> String {
        switch (self, language) {
        case (.clipboardHistory, .japanese): return "全コピー履歴が、\n手元に"
        case (.clipboardHistory, .english):  return "All your clipboard history,\nat your fingertips"
        case (.keyboardPreview, .japanese):  return "キーボードから、\nそのまま貼り付け"
        case (.keyboardPreview, .english):   return "Paste directly\nfrom your keyboard"
        case (.pipMonitoring,   .japanese):  return "使いながら、\n監視を続ける"
        case (.pipMonitoring,   .english):   return "Monitor while\nusing other apps"
        case (.settings,        .japanese):  return "ClipKit Pro で、\nもっと便利に"
        case (.settings,        .english):   return "More features\nwith ClipKit Pro"
        case (.imagePreview,    .japanese):  return "画像も、\nそのまま保存"
        case (.imagePreview,    .english):   return "Images saved\nautomatically"
        case (.keyboardSetup,   .japanese):  return "どのアプリでも、\n使えるキーボード"
        case (.keyboardSetup,   .english):   return "Works in\nevery app"
        case (.favorites,       .japanese):  return "よく使う文章を、\nお気に入りに"
        case (.favorites,       .english):   return "Save your\nfrequent texts"
        case (.widget,          .japanese):  return "ホーム画面に、\nクリップボードを"
        case (.widget,          .english):   return "Your clipboard,\non the home screen"
        }
    }

    var screenshotBackground: AnyView {
        switch self {
        case .clipboardHistory:
            return AnyView(LinearGradient(
                colors: [Color(red: 0.04, green: 0.07, blue: 0.22), Color(red: 0.08, green: 0.13, blue: 0.38)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .keyboardPreview:
            return AnyView(LinearGradient(
                colors: [Color(red: 0.12, green: 0.04, blue: 0.28), Color(red: 0.22, green: 0.08, blue: 0.42)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .pipMonitoring:
            return AnyView(LinearGradient(
                colors: [Color(red: 0.02, green: 0.16, blue: 0.14), Color(red: 0.04, green: 0.24, blue: 0.20)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .settings:
            return AnyView(LinearGradient(
                colors: [Color(red: 0.06, green: 0.06, blue: 0.22), Color(red: 0.14, green: 0.10, blue: 0.35)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .imagePreview:
            return AnyView(LinearGradient(
                colors: [Color(red: 0.22, green: 0.08, blue: 0.04), Color(red: 0.35, green: 0.14, blue: 0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .keyboardSetup:
            return AnyView(LinearGradient(
                colors: [Color(red: 0.04, green: 0.12, blue: 0.28), Color(red: 0.06, green: 0.18, blue: 0.40)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .favorites:
            return AnyView(LinearGradient(
                colors: [Color(red: 0.20, green: 0.14, blue: 0.04), Color(red: 0.30, green: 0.20, blue: 0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .widget:
            return AnyView(LinearGradient(
                colors: [Color(red: 0.04, green: 0.08, blue: 0.22), Color(red: 0.08, green: 0.16, blue: 0.36)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}

// MARK: - iPhone 16 Pro Max Frame
struct PhoneMockupView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 52)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 52)
                        .stroke(Color(white: 0.25), lineWidth: 1.5)
                )

            content()
                .clipShape(RoundedRectangle(cornerRadius: 46))
                .padding(7)

            // Home indicator
            VStack {
                Spacer()
                Capsule()
                    .fill(Color(white: 0.45))
                    .frame(width: 120, height: 5)
                    .padding(.bottom, 9)
            }
        }
    }
}

// MARK: - App Store Screenshot Frame (440×956 pt → 1320×2868 px @3x)
struct AppStoreScreenshotView<Content: View>: View {
    let caption: String
    let background: AnyView
    @ViewBuilder let phoneContent: () -> Content

    var body: some View {
        GeometryReader { geo in
            let captionH = geo.size.height * 0.157
            let availH   = geo.size.height - captionH - 8
            let phoneW   = availH * 430.0 / 932.0

            ZStack {
                background

                VStack(spacing: 0) {
                    Text(caption)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 2, y: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .frame(height: captionH)

                    PhoneMockupView(content: phoneContent)
                        .frame(width: phoneW, height: availH)

                    Spacer().frame(height: 8)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }
}

// MARK: - Status Bar (ImageRenderer safe, no UIKit)
struct MockStatusBar: View {
    var foreground: Color = Color(red: 0.1, green: 0.1, blue: 0.1)

    var body: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(foreground)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(foreground)
        }
        .padding(.horizontal, 22)
        .frame(height: 54)
    }
}

// MARK: - Mock Views
struct MockClipboardHistoryView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                MockStatusBar()
                HStack {
                    Text(language.historyTitle)
                        .font(.largeTitle).bold()
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
            .background(Color.white)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.57))
                    .font(.system(size: 14))
                Text(language.searchPrompt)
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.57))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(red: 0.90, green: 0.90, blue: 0.92))
            .cornerRadius(10)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .background(Color.white)

            // Clip rows
            VStack(spacing: 0) {
                ForEach(0..<8) { index in
                    clipRow(index: index)
                    if index < 7 {
                        Divider().padding(.leading, 72)
                    }
                }
                // Pro upgrade row (hidden for App Store screenshots)
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [.yellow, .orange],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.proUpgradeTitle)
                            .font(.subheadline).bold()
                        Text(language.proUpgradeDescription)
                            .font(.caption)
                            .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.57))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.57))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.yellow.opacity(0.06))
            }
            .background(Color.white)

            Spacer()

            // Custom tab bar
            Rectangle()
                .fill(Color(red: 0.85, green: 0.85, blue: 0.87))
                .frame(height: 0.5)
            HStack(spacing: 0) {
                tabItem(icon: "play.circle.fill",
                        label: language == .japanese ? "常時起動" : "Always On",
                        selected: false)
                tabItem(icon: "clock.fill", label: language.historyTitle, selected: true)
                tabItem(icon: "star.fill",
                        label: language == .japanese ? "お気に入り" : "Favorites",
                        selected: false)
                tabItem(icon: "gearshape.fill", label: language.settings, selected: false)
            }
            .frame(height: 50)
            .background(Color.white)
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
    }

    private func clipRow(index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(itemIconColor(for: index).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: itemIconName(for: index))
                    .font(.system(size: 18))
                    .foregroundColor(itemIconColor(for: index))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(language.sampleText(index))
                        .font(.subheadline)
                        .lineLimit(2)
                    if index == 0 {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                }
                Text(language.sampleTime(index))
                    .font(.caption)
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.57))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
    }

    private func tabItem(icon: String, label: String, selected: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(selected ? .blue : Color(red: 0.6, green: 0.6, blue: 0.62))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(selected ? .blue : Color(red: 0.6, green: 0.6, blue: 0.62))
        }
        .frame(maxWidth: .infinity)
    }

    private func itemIconName(for index: Int) -> String {
        switch index {
        case 1, 8: return "link"
        case 4:    return "photo"
        case 6:    return "doc"
        default:   return "doc.text"
        }
    }

    private func itemIconColor(for index: Int) -> Color {
        switch index {
        case 1, 8: return .purple
        case 4:    return .green
        case 6:    return .orange
        default:   return .blue
        }
    }
}

struct MockKeyboardPreviewView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Notes app area
            VStack(alignment: .leading, spacing: 0) {
                MockStatusBar()
                HStack {
                    Text(language == .japanese ? "メモ" : "Notes")
                        .font(.title).bold()
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text(language == .japanese ? "今日やること" : "Today's Tasks")
                        .font(.subheadline).bold()
                        .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.57))
                    ForEach(language == .japanese
                        ? ["• スーパーで買い物（牛乳・卵・パン）",
                           "• 午後3時 チームミーティング",
                           "• メールを返信する",
                           "• 請求書を確認する"]
                        : ["• Buy groceries (milk, eggs, bread)",
                           "• Team meeting at 3 PM",
                           "• Reply to pending emails",
                           "• Review monthly invoices"],
                        id: \.self) { line in
                        Text(line).font(.body)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                Spacer()
            }
            .frame(maxHeight: .infinity)
            .background(Color.white)

            // ClipKit extension: clip cards (2 rows)
            VStack(spacing: 0) {
                ForEach(0..<2) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<4) { col in
                            let index = row * 4 + col
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: kbIconName(for: index))
                                        .font(.system(size: 10))
                                        .foregroundColor(kbIconColor(for: index))
                                    Spacer()
                                }
                                Text(language.sampleText(index))
                                    .font(.system(size: 10))
                                    .lineLimit(2)
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 76)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                }
                .padding(.bottom, 8)
            }
            .background(Color(red: 0.90, green: 0.91, blue: 0.93))

            // Control bar
            HStack(spacing: 0) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.90, green: 0.91, blue: 0.93))
                    .cornerRadius(8)
                Spacer()
                Image(systemName: "globe")
                    .font(.system(size: 22))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
        }
        .background(Color.white)
    }

    private func kbIconName(for index: Int) -> String {
        ["doc.text", "link", "photo", "envelope"][index % 4]
    }

    private func kbIconColor(for index: Int) -> Color {
        [Color.blue, .green, .orange, .purple][index % 4]
    }
}

struct MockPiPMonitoringView: View {
    let language: AppLanguage

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.3),
                    Color.pink.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                MockStatusBar(foreground: .white)

                // Animated PiP icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: .blue.opacity(0.4), radius: 20, x: 0, y: 10)

                    Image(systemName: "pip.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }

                VStack(spacing: 12) {
                    Text(language.backgroundMonitoring)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(language.pipDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                // Animated status indicator
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)

                    Text(language.monitoringInBackground)
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.green.opacity(0.15))
                .cornerRadius(30)

                // Features list
                VStack(alignment: .leading, spacing: 16) {
                    ScreenshotFeatureRow(icon: "eye.fill", text: language == .english ? "Always monitoring" : "常時監視", color: .blue)
                    ScreenshotFeatureRow(icon: "lock.shield.fill", text: language == .english ? "Secure storage" : "安全なストレージ", color: .green)
                    ScreenshotFeatureRow(icon: "bolt.fill", text: language == .english ? "Quick access" : "素早いアクセス", color: .orange)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding()
        }
    }
}

struct MockSettingsView: View {
    let language: AppLanguage

    private var proSubtitle: String { language == .english ? "Unlock all features" : "すべての機能を解放" }
    private var monthlyLabel: String { language == .english ? "Monthly ¥250/mo" : "月額 ¥250/月" }
    private var yearlyLabel: String { language == .english ? "Yearly ¥2,400/yr" : "年額 ¥2,400/年" }
    private var trialLabel: String { language == .english ? "7-day free trial" : "7日間無料トライアル" }
    private var startTrialLabel: String { language == .english ? "Start Free Trial" : "無料トライアル開始" }
    private var restoreLabel: String { language == .english ? "Restore Purchases" : "購入を復元" }
    private let bgSecondary = Color(red: 0.95, green: 0.95, blue: 0.97)
    private let textSecondary = Color(red: 0.55, green: 0.55, blue: 0.57)

    private var features: [(String, String, String)] {
        language == .english ? [
            ("doc.on.clipboard.fill", "Unlimited History",     "Save up to 100 items"),
            ("magnifyingglass",        "Advanced Search",       "Find anything instantly"),
            ("star.fill",              "Favorites & Pins",      "Pin important clips"),
            ("square.grid.2x2.fill",   "Home Screen Widgets",   "3 widget sizes"),
            ("keyboard.fill",          "Custom Keyboard",       "Access from any app"),
        ] : [
            ("doc.on.clipboard.fill", "無制限の履歴",           "最大100件保存"),
            ("magnifyingglass",        "高度な検索",             "瞬時に見つける"),
            ("star.fill",              "お気に入り・ピン",       "重要なクリップを固定"),
            ("square.grid.2x2.fill",   "ホーム画面ウィジェット", "3サイズ対応"),
            ("keyboard.fill",          "カスタムキーボード",     "どのアプリからでも"),
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.white, Color.blue.opacity(0.05)],
                           startPoint: .top, endPoint: .bottom)

            VStack(spacing: 18) {
                MockStatusBar()
                // Header
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 64, height: 64)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    Text("ClipKit Pro")
                        .font(.title).bold()
                    Text(proSubtitle)
                        .font(.subheadline)
                        .foregroundColor(textSecondary)
                }

                // Feature list
                VStack(spacing: 0) {
                    ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                Image(systemName: f.0)
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(f.1).font(.subheadline).bold()
                                Text(f.2).font(.caption).foregroundColor(textSecondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 18))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        if i < features.count - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .background(bgSecondary)
                .cornerRadius(14)
                .padding(.horizontal, 16)

                // Plan picker
                VStack(spacing: 10) {
                    planRow(title: yearlyLabel, badge: trialLabel, highlighted: true)
                    planRow(title: monthlyLabel, badge: nil, highlighted: false)
                }
                .padding(.horizontal, 16)

                // CTA button
                Text(startTrialLabel)
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(LinearGradient(colors: [.blue, .purple],
                                               startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                Text(restoreLabel)
                    .font(.caption)
                    .foregroundColor(textSecondary)
            }
        }
    }

    private func planRow(title: String, badge: String?, highlighted: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body).bold()
                if let badge = badge {
                    Text(badge).font(.caption).foregroundColor(.green)
                }
            }
            Spacer()
            if highlighted {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
            }
        }
        .padding()
        .background(highlighted ? Color.blue.opacity(0.1) : bgSecondary)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(highlighted ? Color.blue : Color.clear, lineWidth: 2))
        .cornerRadius(12)
    }
}

struct MockImagePreviewView: View {
    let language: AppLanguage

    var body: some View {
        ZStack(alignment: .top) {
            Color.black

            VStack(spacing: 20) {
                Spacer().frame(height: 54 + 44)

                // Mock image
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [.blue, .purple, .pink],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 290, height: 360)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 72))
                                .foregroundColor(.white.opacity(0.8))
                            Text(language == .english ? "Sample Image" : "サンプル画像")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
                    .shadow(color: .white.opacity(0.15), radius: 20, x: 0, y: 10)

                // Image info
                VStack(spacing: 6) {
                    Text(language == .english ? "Photo.jpg" : "写真.jpg")
                        .font(.headline).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Text("1920 × 1080")
                        Text("•")
                        Text("2.4 MB")
                        Text("•")
                        Text("5 " + (language == .english ? "min ago" : "分前"))
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                }

                Spacer()
            }

            // Status bar + nav bar
            VStack(spacing: 0) {
                MockStatusBar(foreground: .white)
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                    Spacer()
                    Text(language.imagePreviewTitle)
                        .font(.headline).foregroundColor(.white)
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 8)
                .frame(height: 44)
            }
            .background(Color.black.opacity(0.8))
        }
    }
}

struct MockKeyboardSetupView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            MockStatusBar(foreground: .blue)
            // Header
            VStack(spacing: 14) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.blue)

                Text(language.keyboardSetupTitle)
                    .font(.title)
                    .fontWeight(.bold)

                Text(language.keyboardDescription)
                    .font(.body)
                    .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.48))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)

            // Steps
            VStack(alignment: .leading, spacing: 24) {
                SetupStepRow(number: 1, text: language.keyboardSetupStep1, icon: "gearshape.fill")
                SetupStepRow(number: 2, text: language.keyboardSetupStep2, icon: "keyboard")
                SetupStepRow(number: 3, text: language.keyboardSetupStep3, icon: "plus.circle.fill")
                SetupStepRow(number: 4, text: language.keyboardSetupStep4, icon: "checkmark.shield.fill")
            }
            .padding(.horizontal, 30)

            Spacer()

            // Bottom button
            Button(action: {}) {
                Text(language == .english ? "Open Settings" : "設定を開く")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .background(Color.white)
    }
}

struct MockFavoritesView: View {
    let language: AppLanguage

    private var title: String { language == .english ? "Favorites" : "お気に入り" }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                MockStatusBar()
                HStack {
                    Text(title)
                        .font(.largeTitle).bold()
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
            .background(Color.white)

            Rectangle()
                .fill(Color(red: 0.85, green: 0.85, blue: 0.87))
                .frame(height: 0.5)

            // Rows (8 items fills the screen nicely)
            VStack(spacing: 0) {
                ForEach(0..<8) { index in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(favIconColor(for: index).opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: favIconName(for: index))
                                .font(.system(size: 18))
                                .foregroundColor(favIconColor(for: index))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(language.sampleText(index))
                                .font(.subheadline)
                                .lineLimit(2)
                            Text(language.sampleTime(index))
                                .font(.caption)
                                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.57))
                        }
                        Spacer()
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    if index < 7 {
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .background(Color.white)

            Spacer()
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
    }

    private func favIconName(for index: Int) -> String {
        ["doc.text", "link", "photo", "doc.text", "link"][index % 5]
    }

    private func favIconColor(for index: Int) -> Color {
        [Color.blue, .green, .orange, .blue, .green][index % 5]
    }
}

// MockWidgetView is a thin wrapper using AppStoreScreenshotView + MockWidgetHomeContent.
struct MockWidgetView: View {
    let language: AppLanguage

    var body: some View {
        AppStoreScreenshotView(
            caption: ScreenshotScreen.widget.caption(language: language),
            background: ScreenshotScreen.widget.screenshotBackground
        ) {
            MockWidgetHomeContent(language: language)
        }
    }
}

// MARK: - Widget Home Screen Content (phone content only)
struct MockWidgetHomeContent: View {
    let language: AppLanguage

    private var recentLabel: String { language == .english ? "Recent Clips" : "最近のクリップ" }
    private var tapToCopyLabel: String { language == .english ? "Tap to copy" : "タップしてコピー" }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.22, blue: 0.75),
                    Color(red: 0.38, green: 0.12, blue: 0.72),
                    Color(red: 0.65, green: 0.15, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                MockStatusBar(foreground: .white)
                mediumWidget
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                Spacer().frame(height: 20)
                smallWidget
                Spacer()
            }
        }
    }

    // MARK: - Widget Views

    private var smallWidget: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(red: 0.10, green: 0.12, blue: 0.28))
            .frame(width: 160, height: 160)
            .overlay(
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                        Text("ClipKit")
                            .font(.caption2).bold().foregroundColor(.white)
                    }
                    Spacer()
                    Text(language.sampleText(0))
                        .font(.caption2)
                        .lineLimit(3)
                        .foregroundColor(.white.opacity(0.9))
                    Text(tapToCopyLabel)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(12)
            )
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
    }

    private var mediumWidget: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(red: 0.10, green: 0.12, blue: 0.28))
            .frame(height: 160)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                        Text(recentLabel)
                            .font(.caption).bold().foregroundColor(.white)
                    }
                    ForEach(0..<3) { i in
                        HStack(spacing: 8) {
                            Image(systemName: i == 1 ? "link" : "doc.text")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                            Text(language.sampleText(i))
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            )
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
    }

}

// MARK: - Helper Views
struct ScreenshotFeatureRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.2))
                .cornerRadius(8)

            Text(text)
                .font(.body)
        }
    }
}

struct SetupStepRow: View {
    let number: Int
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Text("\(number)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(text)
                .font(.body)
                .fontWeight(.medium)

            Spacer()
        }
    }
}

#Preview {
    ScreenshotPreviewView()
}
#endif
