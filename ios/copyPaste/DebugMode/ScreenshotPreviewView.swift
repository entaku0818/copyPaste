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
        switch screen {
        case .clipboardHistory:
            MockClipboardHistoryView(language: language)
        case .keyboardPreview:
            MockKeyboardPreviewView(language: language)
        case .pipMonitoring:
            MockPiPMonitoringView(language: language)
        case .settings:
            MockSettingsView(language: language)
        case .imagePreview:
            MockImagePreviewView(language: language)
        case .keyboardSetup:
            MockKeyboardSetupView(language: language)
        case .favorites:
            MockFavoritesView(language: language)
        case .widget:
            MockWidgetView(language: language)
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

// MARK: - Mock Views
struct MockClipboardHistoryView: View {
    let language: AppLanguage

    var body: some View {
        TabView(selection: .constant(1)) {
            NavigationStack {
                Color.clear
            }
            .tabItem {
                Label(language == .japanese ? "常時起動" : "Always On", systemImage: "play.circle.fill")
            }
            .tag(0)

            NavigationStack {
                List {
                    // Sample clipboard items (9 items)
                    ForEach(0..<9) { index in
                        HStack(spacing: 12) {
                            Image(systemName: itemIconName(for: index))
                                .font(.title2)
                                .foregroundColor(itemIconColor(for: index))
                                .frame(width: 50, height: 50)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(language.sampleText(index))
                                        .font(.body)
                                        .lineLimit(2)
                                    if index == 0 {
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }

                                HStack(spacing: 4) {
                                    Text(language.sampleTime(index))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if index == 4 {
                                        Text("・")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("24 KB")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                    // Pro upgrade banner
                    Section {
                        Button(action: {}) {
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
                                    Text(language.proUpgradeTitle)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(language.proUpgradeDescription)
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
                }
                .navigationTitle(language.historyTitle)
                .searchable(
                    text: .constant(""),
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: language.searchPrompt
                )
            }
            .tabItem {
                Label(language.historyTitle, systemImage: "clock.fill")
            }
            .tag(1)

            NavigationStack {
                Color.clear
            }
            .tabItem {
                Label(language == .japanese ? "お気に入り" : "Favorites", systemImage: "star.fill")
            }
            .tag(2)

            NavigationStack {
                Color.clear
            }
            .tabItem {
                Label(language.settings, systemImage: "gearshape.fill")
            }
            .tag(3)
        }
    }

    private func itemIconName(for index: Int) -> String {
        switch index {
        case 1, 8: return "link"
        case 4: return "photo"
        case 6: return "doc"
        default: return "doc.text"
        }
    }

    private func itemIconColor(for index: Int) -> Color {
        switch index {
        case 1, 8: return .purple
        case 4: return .green
        case 6: return .orange
        default: return .blue
        }
    }
}

struct MockKeyboardPreviewView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // App text area (上部: ノートアプリ風)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(language == .japanese ? "メモ" : "Notes")
                        .font(.title)
                        .fontWeight(.bold)

                    Text(language == .japanese ? "今日やること" : "Today's Tasks")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(language == .japanese
                            ? ["• スーパーで買い物（牛乳・卵・パン）",
                               "• 午後3時 チームミーティング",
                               "• メールを返信する",
                               "• 請求書を確認する",
                               "• 薬を飲む"]
                            : ["• Buy groceries (milk, eggs, bread)",
                               "• Team meeting at 3 PM",
                               "• Reply to pending emails",
                               "• Review monthly invoices",
                               "• Take medication"],
                            id: \.self
                        ) { line in
                            Text(line)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }

                    Divider()
                        .padding(.top, 4)

                    Text(language == .japanese
                         ? "最後にコピー: https://www.apple.com/jp/"
                         : "Last copied: https://www.apple.com")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // クリップボード履歴カード
                    VStack(spacing: 8) {
                        ForEach(0..<4) { index in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(iconColor(for: index).opacity(0.15))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: iconName(for: index))
                                        .font(.system(size: 13))
                                        .foregroundColor(iconColor(for: index))
                                }
                                Text(language.sampleText(index))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Spacer()
                                Text(language == .japanese
                                     ? [" 1分前", " 5分前", "10分前", "30分前"][index]
                                     : ["1m ago", "5m ago", "10m ago", "30m ago"][index])
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .frame(maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))

            // キーボード領域: グレー背景でiOSキーボード展開状態を表現 (案C)
            Color(UIColor.systemGray5)
                .frame(height: 260)

            // ClipKit キーボード拡張: 横スクロールカード
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<8) { index in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(iconColor(for: index).opacity(0.2))
                                        .frame(width: 24, height: 24)

                                    Image(systemName: iconName(for: index))
                                        .font(.system(size: 12))
                                        .foregroundColor(iconColor(for: index))
                                }
                                Spacer()
                            }

                            Text(language.sampleText(index))
                                .lineLimit(2)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .frame(width: 120, height: 80)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(height: 100)
            .background(
                LinearGradient(
                    colors: [Color(UIColor.secondarySystemBackground), Color(UIColor.tertiarySystemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // コントロールバー
            HStack(spacing: 16) {
                Button(action: {}) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "globe")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }

                Spacer().frame(width: 20)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func iconName(for index: Int) -> String {
        let icons = ["doc.text", "link", "photo", "doc.text", "link", "envelope", "phone", "doc.plaintext"]
        return icons[index % icons.count]
    }

    private func iconColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .blue, .green, .purple, .pink, .blue]
        return colors[index % colors.count]
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
                Spacer()

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

    private var proTitle: String { language == .english ? "ClipKit Pro" : "ClipKit Pro" }
    private var proSubtitle: String { language == .english ? "Unlock all features" : "すべての機能を解放" }
    private var freeLabel: String { language == .english ? "Free" : "無料版" }
    private var proLabel: String { language == .english ? "Pro" : "Pro版" }
    private var monthlyLabel: String { language == .english ? "Monthly ¥250/mo" : "月額 ¥250/月" }
    private var yearlyLabel: String { language == .english ? "Yearly ¥2,400/yr" : "年額 ¥2,400/年" }
    private var trialLabel: String { language == .english ? "7-day free trial" : "7日間無料トライアル" }
    private var startTrialLabel: String { language == .english ? "Start Free Trial" : "無料トライアル開始" }
    private var restoreLabel: String { language == .english ? "Restore Purchases" : "購入を復元" }

    private var features: [(String, String, String)] {
        language == .english ? [
            ("doc.on.clipboard.fill",  "Unlimited History",      "Save up to 100 items"),
            ("magnifyingglass",         "Advanced Search",        "Find anything instantly"),
            ("star.fill",               "Favorites & Pins",       "Pin important clips"),
            ("square.grid.2x2.fill",    "Home Screen Widgets",    "3 widget sizes"),
            ("keyboard.fill",           "Custom Keyboard",        "Access from any app"),
        ] : [
            ("doc.on.clipboard.fill",  "無制限の履歴",            "最大100件保存"),
            ("magnifyingglass",         "高度な検索",              "瞬時に見つける"),
            ("star.fill",               "お気に入り・ピン",        "重要なクリップを固定"),
            ("square.grid.2x2.fill",    "ホーム画面ウィジェット",  "3サイズ対応"),
            ("keyboard.fill",           "カスタムキーボード",      "どのアプリからでも"),
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(uiColor: .systemBackground), Color.blue.opacity(0.05)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        Text(proTitle)
                            .font(.largeTitle).bold()
                        Text(proSubtitle)
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    // Feature list
                    VStack(spacing: 0) {
                        ForEach(features, id: \.0) { icon, title, sub in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: icon)
                                        .foregroundColor(.blue)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title).font(.body).bold()
                                    Text(sub).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            if icon != features.last?.0 {
                                Divider().padding(.leading, 74)
                            }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)

                    // Plan picker
                    VStack(spacing: 12) {
                        planButton(title: yearlyLabel, badge: trialLabel, highlighted: true)
                        planButton(title: monthlyLabel, badge: nil, highlighted: false)
                    }
                    .padding(.horizontal, 20)

                    // CTA
                    Button(action: {}) {
                        Text(startTrialLabel)
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 20)

                    Button(restoreLabel) {}
                        .font(.caption).foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
            }
        }
    }

    @ViewBuilder
    private func planButton(title: String, badge: String?, highlighted: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
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
        .background(highlighted ? Color.blue.opacity(0.1) : Color(uiColor: .secondarySystemBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(highlighted ? Color.blue : Color.clear, lineWidth: 2))
        .cornerRadius(12)
    }
}

struct MockImagePreviewView: View {
    let language: AppLanguage

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    // Mock image with gradient
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 300, height: 400)
                        .overlay(
                            VStack {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.white.opacity(0.8))
                                Text(language == .english ? "Sample Image" : "サンプル画像")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )
                        .shadow(color: .white.opacity(0.2), radius: 20, x: 0, y: 10)

                    // Image info
                    VStack(spacing: 8) {
                        Text(language == .english ? "Photo.jpg" : "写真.jpg")
                            .font(.headline)
                            .foregroundColor(.white)

                        HStack(spacing: 16) {
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
            }
            .navigationTitle(language.imagePreviewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

struct MockKeyboardSetupView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text(language.keyboardSetupTitle)
                    .font(.title)
                    .fontWeight(.bold)

                Text(language.keyboardDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .padding(.top, 60)
            .padding(.bottom, 40)

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
        .background(Color(UIColor.systemBackground))
    }
}

struct MockFavoritesView: View {
    let language: AppLanguage

    private var title: String { language == .english ? "Favorites" : "お気に入り" }
    private var emptyMessage: String { language == .english ? "No favorites yet" : "お気に入りはまだありません" }

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<5) { index in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(iconColor(for: index).opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: iconName(for: index))
                                .font(.system(size: 18))
                                .foregroundColor(iconColor(for: index))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(language.sampleText(index))
                                .font(.body)
                                .lineLimit(2)
                            Text(language.sampleTime(index))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 16))
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "gearshape.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
    }

    private func iconName(for index: Int) -> String {
        let icons = ["doc.text", "link", "photo", "doc.text", "link"]
        return icons[index % icons.count]
    }

    private func iconColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .blue, .green]
        return colors[index % colors.count]
    }
}

struct MockWidgetView: View {
    let language: AppLanguage

    private var recentLabel: String { language == .english ? "Recent Clips" : "最近のクリップ" }
    private var tapToCopyLabel: String { language == .english ? "Tap to copy" : "タップしてコピー" }

    // ダミーアプリアイコン定義
    private let iconData: [(symbol: String, colors: [Color])] = [
        ("message.fill",      [.green, Color(red: 0.2, green: 0.8, blue: 0.4)]),
        ("phone.fill",        [Color(red: 0.2, green: 0.8, blue: 0.2), .green]),
        ("safari.fill",       [.blue, Color(red: 0.1, green: 0.5, blue: 1.0)]),
        ("envelope.fill",     [Color(red: 0.1, green: 0.5, blue: 1.0), .blue]),
        ("music.note",        [Color(red: 0.95, green: 0.2, blue: 0.3), .pink]),
        ("map.fill",          [Color(red: 0.2, green: 0.75, blue: 0.3), .teal]),
        ("camera.fill",       [Color(red: 0.3, green: 0.3, blue: 0.35), Color(red: 0.5, green: 0.5, blue: 0.55)]),
        ("photo.fill",        [.orange, .yellow]),
        ("note.text",         [Color(red: 1.0, green: 0.85, blue: 0.1), .orange]),
        ("list.bullet",       [Color(red: 0.95, green: 0.3, blue: 0.3), .red]),
        ("calendar",          [Color(red: 0.95, green: 0.3, blue: 0.3), Color(red: 1.0, green: 0.5, blue: 0.4)]),
        ("gearshape.fill",    [Color(red: 0.55, green: 0.55, blue: 0.6), Color(red: 0.4, green: 0.4, blue: 0.45)]),
    ]

    var body: some View {
        ZStack {
            // iOSホーム画面風グラデーション壁紙
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.22, blue: 0.75),
                    Color(red: 0.38, green: 0.12, blue: 0.72),
                    Color(red: 0.65, green: 0.15, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                // アプリアイコン行 1
                iconRow(indices: [0, 1, 2, 3])

                Spacer().frame(height: 20)

                // ミディアムウィジェット
                mediumWidget
                    .padding(.horizontal, 20)

                Spacer().frame(height: 20)

                // アプリアイコン行 2
                iconRow(indices: [4, 5, 6, 7])

                Spacer().frame(height: 20)

                // スモールウィジェット + アイコン2列
                HStack(spacing: 16) {
                    Spacer().frame(width: 4)
                    smallWidget
                    Spacer()
                    VStack(spacing: 16) {
                        dummyIcon(index: 8)
                        dummyIcon(index: 9)
                    }
                    VStack(spacing: 16) {
                        dummyIcon(index: 10)
                        dummyIcon(index: 11)
                    }
                    Spacer().frame(width: 4)
                }
                .padding(.horizontal, 12)

                Spacer()

                // ドック
                HStack(spacing: 0) {
                    ForEach([0, 2, 4, 6], id: \.self) { i in
                        Spacer()
                        dummyIcon(index: i)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Widget Views

    private var smallWidget: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.ultraThinMaterial)
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
            .fill(.ultraThinMaterial)
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

    // MARK: - Helpers

    private func iconRow(indices: [Int]) -> some View {
        HStack(spacing: 0) {
            ForEach(indices, id: \.self) { i in
                Spacer()
                dummyIcon(index: i)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private func dummyIcon(index: Int) -> some View {
        let data = iconData[index % iconData.count]
        return ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: data.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
            Image(systemName: data.symbol)
                .font(.system(size: 26))
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
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
