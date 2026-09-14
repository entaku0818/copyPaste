import SwiftUI

/// アプリ起動・バックグラウンドからの復帰で App Open 広告の表示機会を通知する。
///
/// - コールドスタートは `scenePhase` が最初から `.active` で `onChange` が飛ばないため `.task` で拾う。
/// - 復帰は **`.background` からの遷移だけ** を数える。コントロールセンターを開いた時などの
///   `.inactive` → `.active` や、全画面広告を閉じた直後の復帰で二重に数えないため。
struct AppOpenAdLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task {
                await notifyForeground()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                guard oldPhase == .background, newPhase == .active else { return }
                Task { await notifyForeground() }
            }
    }

    private func notifyForeground() async {
        await AppOpenAdManager.shared.handleForeground(
            isProUser: RevenueCatManager.shared.hasProAccess()
        )
    }
}

extension View {
    /// App Open 広告の表示機会をこのViewのライフサイクルに紐づける
    func appOpenAdLifecycle() -> some View {
        modifier(AppOpenAdLifecycleModifier())
    }
}
