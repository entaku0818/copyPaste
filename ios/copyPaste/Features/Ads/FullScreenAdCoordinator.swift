import Foundation
import os
import UIKit

/// 全画面広告（インタースティシャル / アプリ起動）の相互排他を一元管理する。
///
/// app_openは起動・復帰時、interstitialはタブ切り替え時に出るため、
/// 「起動直後にapp_open → すぐタブを切り替えてinterstitial」で2枚連続して出る事故が起きうる。
/// 両方のManagerが表示前に必ずここへ問い合わせることで、それを構造的に防ぐ。
///
/// - `isPresenting`: どちらかが画面に出ている間はtrue。広告を閉じた直後の
///   フォアグラウンド復帰でもう1枚出る、という定番の事故も同時に防ぐ。
/// - `lastPresentedAt`: **フォーマットを問わず**最後に全画面広告を出した時刻。
///   各フォーマットはここからの経過時間で自分の表示可否を決める。
@MainActor
final class FullScreenAdCoordinator {
    static let shared = FullScreenAdCoordinator()

    private static let logger = Logger(subsystem: "com.entaku.clipkit", category: "FullScreenAd")

    private enum Key {
        static let lastPresentedAt = "clipkit.fullScreenAd.lastPresentedAt"
    }

    private let defaults: UserDefaults

    /// 全画面広告を表示中、または表示を試みている最中か
    private(set) var isPresenting = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// フォーマットを問わず、最後に全画面広告を表示した時刻
    var lastPresentedAt: Date? {
        get { defaults.object(forKey: Key.lastPresentedAt) as? Date }
        set { defaults.set(newValue, forKey: Key.lastPresentedAt) }
    }

    /// 直前の全画面広告から `minimumGap` 秒以上空いていて、かつ今どれも出ていないか
    func canPresent(minimumGap: TimeInterval, now: Date = Date()) -> Bool {
        guard !isPresenting else { return false }
        guard let lastPresentedAt else { return true }
        return now.timeIntervalSince(lastPresentedAt) >= minimumGap
    }

    /// `present(from:)` を呼ぶ直前に必ず呼ぶ。デリゲート通知を待つ間の割り込みを塞ぐ
    func markPresentAttempt() {
        isPresenting = true
    }

    /// 実際に画面へ出た（`adWillPresentFullScreenContent`）
    func markPresented(now: Date = Date()) {
        isPresenting = true
        lastPresentedAt = now
    }

    /// 表示に失敗した。出ていないので間隔は記録しない
    func markPresentFailed() {
        isPresenting = false
    }

    /// 閉じられた
    func markDismissed() {
        isPresenting = false
    }

    /// 実際に広告を載せられる最前面のVCを返す（シートやフルスクリーンカバーを考慮）
    func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        // 画面遷移の途中で present するとSDK側で失敗するので見送る
        guard let top, !top.isBeingDismissed, !top.isBeingPresented else { return nil }
        return top
    }
}
