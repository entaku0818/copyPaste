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

    var clearButton: String {
        switch self {
        case .english: return "Clear"
        case .japanese: return "クリア"
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

    func sampleText(_ index: Int) -> String {
        switch self {
        case .english:
            return ["Hello World", "https://example.com", "Sample text for testing", "Important note", "Quick memo"][index % 5]
        case .japanese:
            return ["こんにちは世界", "https://example.com", "テスト用のサンプルテキスト", "重要なメモ", "クイックメモ"][index % 5]
        }
    }

    func sampleTime(_ index: Int) -> String {
        let times = ["1 min ago", "5 min ago", "10 min ago", "30 min ago", "1 hour ago"]
        let timesJa = ["1分前", "5分前", "10分前", "30分前", "1時間前"]
        return self == .english ? times[index % 5] : timesJa[index % 5]
    }
}

// MARK: - Screenshot Screen Enum
enum ScreenshotScreen: String, CaseIterable {
    case clipboardHistory
    case keyboardPreview
    case pipMonitoring
}

// MARK: - Mock Views
struct MockClipboardHistoryView: View {
    let language: AppLanguage

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        // Mock video player
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black)
                            .frame(height: 100)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
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

                // Sample clipboard items
                ForEach(0..<5) { index in
                    HStack(spacing: 12) {
                        Image(systemName: index == 1 ? "link" : "doc.text")
                            .font(.title2)
                            .foregroundColor(index == 1 ? .green : .blue)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(language.sampleText(index))
                                .font(.body)
                                .lineLimit(2)

                            Text(language.sampleTime(index))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(language.appTitle)
            .toolbar {
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

                    Button(language.clearButton) {}
                }
            }
        }
    }
}

struct MockKeyboardPreviewView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // App header
            HStack {
                Text(language.keyboardExtension)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemBackground))

            Spacer()

            // Mock keyboard
            VStack(spacing: 0) {
                // Clipboard history area
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<5) { index in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: index == 1 ? "link" : "doc.text")
                                        .foregroundColor(index == 1 ? .green : .blue)
                                    Spacer()
                                }

                                Text(language.sampleText(index))
                                    .lineLimit(2)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(8)
                            .frame(width: 120, height: 80)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(height: 100)
                .background(Color(UIColor.secondarySystemBackground))

                // Keyboard controls
                HStack {
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "globe")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }
                    Spacer().frame(width: 20)
                }
                .padding(.vertical, 8)
                .background(Color(UIColor.systemBackground))
            }

            Text(language.keyboardDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct MockPiPMonitoringView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Large PiP icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "pip.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            Text(language.backgroundMonitoring)
                .font(.title)
                .fontWeight(.bold)

            Text(language.pipDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Status indicator
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)

                Text(language.monitoringInBackground)
                    .font(.headline)
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(25)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    ScreenshotPreviewView()
}
#endif
