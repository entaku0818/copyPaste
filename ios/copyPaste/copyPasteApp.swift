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
    init() {
        // RevenueCatの初期化
        RevenueCatManager.shared.configure()
        // AdMobの初期化
        AdManager.shared.configure()
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
            } else {
                ContentView(
                    store: Store(
                        initialState: ClipboardHistoryFeature.State()
                    ) {
                        ClipboardHistoryFeature()
                    }
                )
            }
            #else
            ContentView(
                store: Store(
                    initialState: ClipboardHistoryFeature.State()
                ) {
                    ClipboardHistoryFeature()
                }
            )
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
        }
    }
    #endif
}
