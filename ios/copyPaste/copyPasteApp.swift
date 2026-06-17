//
//  copyPasteApp.swift
//  copyPaste
//
//  Created by 遠藤拓弥 on 2025/05/02.
//

import SwiftUI
import ComposableArchitecture
import FirebaseCore
import FirebaseAnalytics

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
    return true
  }
}


@main
struct ClipKitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let store = Store(
        initialState: ClipboardHistoryFeature.State()
    ) {
        ClipboardHistoryFeature()
    }

    init() {
        RevenueCatManager.shared.configure()
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
        AppStoreScreenshotView(
            caption: screen.caption(language: language),
            background: screen.screenshotBackground
        ) {
            screenshotContent(for: screen, language: language)
        }
    }
    #endif
}
