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
}

// MARK: - Mock Views
struct MockClipboardHistoryView: View {
    let language: AppLanguage

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        // Mock video player with gradient
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 100)
                            .overlay(
                                VStack {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                    Text("PiP Video")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            )

                        // PiP status
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)

                            Text(language.pipActive)
                                .font(.caption)
                                .foregroundColor(.green)

                            Spacer()

                            Text(language.monitoringInBackground)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text(language.backgroundMonitoring)
                } footer: {
                    Text(language.pipDescription)
                        .font(.caption2)
                }

                // Sample clipboard items - 10 items for better showcase
                ForEach(0..<10) { index in
                    HStack(spacing: 12) {
                        // Icon based on type
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

                        // Size indicator for some items
                        if index % 3 == 0 {
                            Text("\(Int.random(in: 10...999)) KB")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(language.appTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "gearshape.fill")
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text(language.monitoring)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Button(language.stopButton) {}
                        .tint(.red)
                }
            }
        }
    }

    private func iconName(for index: Int) -> String {
        let icons = ["doc.text", "link", "photo", "doc.text", "link", "envelope", "phone", "doc.plaintext", "link", "note.text"]
        return icons[index % icons.count]
    }

    private func iconColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .blue, .green, .purple, .pink, .blue, .green, .cyan]
        return colors[index % colors.count]
    }
}

struct MockKeyboardPreviewView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Mock text input area
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Sample text from clipboard...")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(UIColor.systemBackground))

            Spacer()

            // Mock keyboard
            VStack(spacing: 0) {
                // Clipboard history area with better visuals
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

                // Keyboard controls with better styling
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

            Text(language.keyboardDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
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
                    FeatureRow(icon: "eye.fill", text: language == .english ? "Always monitoring" : "常時監視", color: .blue)
                    FeatureRow(icon: "lock.shield.fill", text: language == .english ? "Secure storage" : "安全なストレージ", color: .green)
                    FeatureRow(icon: "bolt.fill", text: language == .english ? "Quick access" : "素早いアクセス", color: .orange)
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

    var body: some View {
        NavigationStack {
            List {
                // App Info Section
                Section {
                    HStack {
                        Text(language.version)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(language.build)
                        Spacer()
                        Text("100")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(language.appInfo)
                }

                // Debug Section
                Section {
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text(language.screenshotPreview)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(language.debug)
                } footer: {
                    Text(language == .english ? "Preview App Store screenshots" : "App Store用のスクリーンショットをプレビューできます")
                        .font(.caption)
                }
            }
            .navigationTitle(language.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.done) {}
                }
            }
        }
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

// MARK: - Helper Views
struct FeatureRow: View {
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

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                    Text(icon.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    ScreenshotPreviewView()
}
#endif
