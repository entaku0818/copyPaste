import Foundation
import GoogleMobileAds
import os
import UIKit

/// アプリ起動（App Open）広告管理
///
/// 実測でapp_openのeCPMはバナーの約20倍。ClipKitにはbanner/interstitialしか無かったため追加した。
///
/// 設計上の決まりごと:
/// - **ロード待ちを必ず入れる**。App Open広告の取得には1〜2秒かかるので、起動直後に
///   「未ロードなら即諦める」実装にすると表示率がほぼ0になる（他アプリで実際に0.2%だった）。
///   ここでは最大4秒待つ。
/// - **専用カウンタキーを使う**。`AppReview` の `clipkit.launchCount` とは共有しない
///   （キー共有で表示機会が消え、課金訴求まで誤爆した事例がある）。
/// - **Proユーザーには出さない**。
/// - **表示されうるユーザーにだけプリロードする**。次のフォアグラウンドが表示回になる時だけ先読みする。
/// - **他の全画面広告との相互排他**は `FullScreenAdCoordinator` に集約している。
@MainActor
final class AppOpenAdManager: NSObject, ObservableObject {
    static let shared = AppOpenAdManager()

    private static let logger = Logger(subsystem: "com.entaku.clipkit", category: "AppOpenAd")

    private enum Key {
        /// AppReviewの起動カウンタとは絶対に共有しない専用キー
        static let foregroundCount = "clipkit.appOpenAd.foregroundCount"
    }

    /// 何回に1回出すか
    static let showInterval = 5
    /// 未ロードだった時に待つ上限
    private let loadTimeout: TimeInterval = 4
    /// 直前の全画面広告（フォーマット問わず）から空けたい最低間隔
    private let minimumGapFromOtherAd: TimeInterval = 10 * 60
    /// App Open広告は4時間で期限切れになる
    private let adLifetime: TimeInterval = 4 * 60 * 60

    private var adUnitID: String {
        AdManager.appOpenAdUnitID
    }

    private let coordinator: FullScreenAdCoordinator
    private var ad: AppOpenAd?
    private var loadedAt: Date?
    private var isLoading = false

    init(coordinator: FullScreenAdCoordinator = .shared) {
        self.coordinator = coordinator
        super.init()
    }

    private var foregroundCount: Int {
        get { UserDefaults.standard.integer(forKey: Key.foregroundCount) }
        set { UserDefaults.standard.set(newValue, forKey: Key.foregroundCount) }
    }

    private var isExpired: Bool {
        guard let loadedAt else { return false }
        return Date().timeIntervalSince(loadedAt) > adLifetime
    }

    /// この回数が表示回にあたるか（起動N回に1回）
    static func isShowOpportunity(count: Int) -> Bool {
        count > 0 && count % showInterval == 0
    }

    /// 次のフォアグラウンドが表示回になるか（先読みしてよいか）
    static func shouldPreload(after count: Int) -> Bool {
        isShowOpportunity(count: count + 1)
    }

    /// アプリがフォアグラウンドになった時に呼ぶ（コールドスタート含む）
    func handleForeground(isProUser: Bool) async {
        // Proユーザーには出さないし、ロードもしない
        guard !isProUser else { return }
        guard !adUnitID.isEmpty else { return }

        // 広告を閉じた直後の復帰でもう1枚出さない
        guard !coordinator.isPresenting else { return }

        foregroundCount += 1
        let count = foregroundCount

        guard Self.isShowOpportunity(count: count) else {
            // 表示されうるユーザーにだけプリロードする（無駄打ちを避ける）
            if Self.shouldPreload(after: count), coordinator.canPresent(minimumGap: minimumGapFromOtherAd) {
                await loadAd()
            }
            return
        }

        // 直前に他の全画面広告（interstitial）を出していたら見送る
        guard coordinator.canPresent(minimumGap: minimumGapFromOtherAd) else {
            Self.logger.info("AppOpenAd skipped: another full screen ad was shown recently")
            return
        }

        if isExpired {
            discardAd()
        }

        if ad == nil {
            // 未ロードなら上限付きで待つ。ここを待たないと表示率がほぼ0になる
            await loadAdWaitingForCompletion()
        }

        showAdIfPossible()
    }

    /// 広告をプリロード（ロード済みならスキップ）
    func loadAd() async {
        guard ad == nil, !isLoading, !adUnitID.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await AppOpenAd.load(with: adUnitID, request: Request())
            loaded.fullScreenContentDelegate = self
            ad = loaded
            loadedAt = Date()
        } catch {
            Self.logger.error("AppOpenAd failed to load: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// ロードを開始し、完了か上限時間のどちらか早い方まで待つ
    private func loadAdWaitingForCompletion() async {
        if !isLoading {
            Task { await loadAd() }
        }
        let deadline = Date().addingTimeInterval(loadTimeout)
        while ad == nil, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
            if !isLoading, ad == nil {
                // ロードが失敗して終わった
                break
            }
        }
    }

    private func showAdIfPossible() {
        guard let ad else {
            Self.logger.info("AppOpenAd not ready within \(self.loadTimeout, privacy: .public)s")
            return
        }
        guard let presenter = coordinator.topViewController() else {
            Self.logger.error("AppOpenAd: no presentable view controller")
            return
        }
        do {
            try ad.canPresent(from: presenter)
        } catch {
            Self.logger.error("AppOpenAd cannot present: \(error.localizedDescription, privacy: .public)")
            return
        }
        // デリゲート通知が返るまでの間に他の全画面広告が割り込まないよう先に押さえる
        coordinator.markPresentAttempt()
        ad.present(from: presenter)
    }

    private func discardAd() {
        ad = nil
        loadedAt = nil
    }

    #if DEBUG
    /// E2Eテスト用。フォアグラウンド回数と在庫を初期化する
    func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: Key.foregroundCount)
        discardAd()
    }
    #endif
}

// MARK: - FullScreenContentDelegate

extension AppOpenAdManager: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        coordinator.markPresented()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Self.logger.error("AppOpenAd failed to present: \(error.localizedDescription, privacy: .public)")
        coordinator.markPresentFailed()
        discardAd()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        coordinator.markDismissed()
        // 一度表示した広告は再利用できない。次の表示回の手前で改めて先読みする
        discardAd()
    }
}
