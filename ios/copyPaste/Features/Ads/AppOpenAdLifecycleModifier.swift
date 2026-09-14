import SwiftUI

/// アプリ起動・バックグラウンドからの復帰で App Open 広告の表示機会を通知する。
///
/// - コールドスタートは `scenePhase` が最初から `.active` で `onChange` が飛ばないため `.task` で拾う。
/// - 復帰は **一度 `.background` に落ちた場合だけ** 数える。コントロールセンターを開いた時などの
///   `.inactive` → `.active` や、全画面広告を閉じた直後の復帰で二重に数えないため。
///
/// `oldPhase == .background && newPhase == .active` という条件では**動かない**。
/// iOSは `.background` → `.inactive` → `.active` と段階を踏むため、
/// `.background` から直接 `.active` に変わる遷移は一度も観測されない
/// （実機E2Eで復帰が1回も数えられていないことが分かり判明）。
struct AppOpenAdLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var didEnterBackground = false

    func body(content: Content) -> some View {
        content
            .task {
                await notifyForeground()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    didEnterBackground = true
                case .active:
                    // .inactive を経由しても取りこぼさない
                    guard didEnterBackground else { return }
                    didEnterBackground = false
                    Task { await notifyForeground() }
                default:
                    break
                }
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
