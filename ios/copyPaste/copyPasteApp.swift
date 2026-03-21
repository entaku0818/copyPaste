//
//  copyPasteApp.swift
//  copyPaste
//
//  Created by 遠藤拓弥 on 2025/05/02.
//

import SwiftUI
import ComposableArchitecture

@main
struct copyPasteApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let store = Store(
        initialState: ClipboardHistoryFeature.State()
    ) {
        ClipboardHistoryFeature()
    }

    init() {
        // RevenueCatの初期化
        RevenueCatManager.shared.configure()
        // AdMobの初期化
        AdManager.shared.configure()
    }

    private var mainView: some View {
        ContentView(store: store)
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--screenshots") {
                let args = ProcessInfo.processInfo.arguments
                let screenIndex = args.firstIndex(of: "--screen").flatMap { Int(args[$0 + 1]) } ?? 0
                let screens = ScreenshotScreen.allCases
                let screen = screens[min(screenIndex, screens.count - 1)]
                screenshotView(for: screen, language: .japanese)
            } else if hasCompletedOnboarding {
                mainView
                    .onOpenURL { url in
                        if url.scheme == "clipkit", url.host == "subscription" {
                            store.send(.showPaywall)
                        }
                    }
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
            #else
            if hasCompletedOnboarding {
                mainView
                    .onOpenURL { url in
                        // clipkit://subscription → Paywall表示（キーボード拡張からの遷移）
                        if url.scheme == "clipkit", url.host == "subscription" {
                            store.send(.showPaywall)
                        }
                    }
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
            #endif
        }
    }

    #if DEBUG
    @ViewBuilder
    private func screenshotView(for screen: ScreenshotScreen, language: AppLanguage) -> some View {
        switch screen {
        case .clipboardHistory: MockClipboardHistoryView(language: language)
        case .keyboardPreview:  MockKeyboardPreviewView(language: language)
        case .pipMonitoring:    MockPiPMonitoringView(language: language)
        case .settings:         MockSettingsView(language: language)
        case .imagePreview:     MockImagePreviewView(language: language)
        case .keyboardSetup:    MockKeyboardSetupView(language: language)
        case .favorites:        MockFavoritesView(language: language)
        case .widget:           MockWidgetView(language: language)
        }
    }
    #endif
}
