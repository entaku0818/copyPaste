import Foundation
import GoogleMobileAds
import os
import UIKit

/// インタースティシャル広告管理
///
/// 表示タイミングの方針:
/// - **コピー直後には出さない**。履歴からコピーした瞬間はユーザーが他アプリへ移る瞬間で、
///   ここを全画面広告で塞ぐとClipKitの中核体験（時短）を壊す。
/// - コピー回数は永続カウントし、閾値を超えたら「保留中」にするだけ。
///   実際の表示は `showPendingAd(isProUser:)` を呼ぶ自然な遷移点（タブ切り替え）に任せる。
/// - 表示可否は `FullScreenAdCoordinator` を通す。app_openと2枚続けて出ないようにするため。
///
/// 過去の不具合（30日で576リクエスト / 表示0件）:
/// コピー直後に keyWindow の rootViewController から present していたため、
/// 詳細シートが載っている状態＝`presentedViewController != nil` で必ず present に失敗していた。
/// `fullScreenContentDelegate` も未設定でエラーが握り潰され、失敗のたびに広告を捨てて
/// 再ロードしていたためリクエストだけが積み上がっていた。
@MainActor
final class InterstitialAdManager: NSObject, ObservableObject {
    static let shared = InterstitialAdManager()

    private static let logger = Logger(subsystem: "com.entaku.clipkit", category: "InterstitialAd")

    private enum Key {
        static let copyCount = "clipkit.interstitial.copyCount"
    }

    /// 広告を保留状態にするまでに必要なコピー回数
    private let showInterval = 5
    /// 前回の全画面広告（app_open含む・フォーマット問わず）からの最低間隔。
    /// 起動直後のapp_openとタブ切替のinterstitialが2枚続けて出る事故をここで塞ぐ
    private let minimumInterval: TimeInterval = 30 * 60
    /// AdMobのインタースティシャルは約1時間で期限切れになる
    private let adLifetime: TimeInterval = 55 * 60

    private var adUnitID: String {
        AdManager.interstitialAdUnitID
    }

    private let coordinator: FullScreenAdCoordinator
    private var interstitial: InterstitialAd?
    private var loadedAt: Date?
    private var isLoading = false

    private var copyCount: Int {
        get { UserDefaults.standard.integer(forKey: Key.copyCount) }
        set { UserDefaults.standard.set(newValue, forKey: Key.copyCount) }
    }

    /// 閾値に達していて、あとは自然な遷移点を待つだけの状態か
    private var isPending: Bool {
        copyCount >= showInterval
    }

    private var isExpired: Bool {
        guard let loadedAt else { return false }
        return Date().timeIntervalSince(loadedAt) > adLifetime
    }

    init(coordinator: FullScreenAdCoordinator = .shared) {
        self.coordinator = coordinator
        super.init()
    }

    /// 広告をプリロード（ロード済みならスキップ）
    func loadAd() async {
        guard interstitial == nil, !isLoading, !adUnitID.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let ad = try await InterstitialAd.load(with: adUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            interstitial = ad
            loadedAt = Date()
        } catch {
            Self.logger.error("InterstitialAd failed to load: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// アイテムをコピー／ペーストした時に呼ぶ。カウントするだけで表示はしない
    func onItemPasted(isProUser: Bool) {
        // Pro版は広告なし
        guard !isProUser else { return }

        copyCount += 1
        // 閾値に達したら、次の遷移点ですぐ出せるよう在庫を用意しておく
        if isPending {
            Task { await loadAd() }
        }
    }

    /// 自然な遷移点（タブ切り替えなど）で呼ぶ。条件を満たしていれば保留中の広告を表示する
    func showPendingAd(isProUser: Bool) {
        guard !isProUser, isPending else { return }

        // app_openを含むすべての全画面広告と相互排他。直前に他の広告が出ていたら見送る
        guard coordinator.canPresent(minimumGap: minimumInterval) else {
            Self.logger.info("InterstitialAd skipped: another full screen ad was shown recently")
            return
        }

        if isExpired {
            // 期限切れの在庫は present しても必ず失敗するので捨てて取り直す
            discardAd()
            Task { await loadAd() }
            return
        }

        guard let interstitial else {
            Task { await loadAd() }
            return
        }

        guard let presenter = coordinator.topViewController() else {
            Self.logger.error("InterstitialAd: no presentable view controller")
            return
        }

        do {
            // 表示できない状況（別のVCを提示中など）を握り潰さず、広告も捨てない
            try interstitial.canPresent(from: presenter)
        } catch {
            Self.logger.error("InterstitialAd cannot present: \(error.localizedDescription, privacy: .public)")
            return
        }

        // デリゲート通知が返るまでの間にapp_openが割り込まないよう先に押さえる
        coordinator.markPresentAttempt()
        interstitial.present(from: presenter)
    }

    private func discardAd() {
        interstitial = nil
        loadedAt = nil
    }

    #if DEBUG
    /// E2Eテスト用。コピー回数と在庫を初期化する
    func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: Key.copyCount)
        discardAd()
    }

    /// E2Eテスト用。コピー回数を閾値まで進めて「保留中」にし、在庫を先読みする。
    /// 履歴にアイテムを入れるにはクリップボード監視が要るが、監視を動かすと
    /// XCUITestのidle待ちが終わらなくなるため、コピー操作を迂回するための入り口。
    func seedPendingForTesting() {
        copyCount = showInterval
        Task { await loadAd() }
    }
    #endif
}

// MARK: - FullScreenContentDelegate

extension InterstitialAdManager: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        // 表示できた時点でカウンタをリセットし、全画面広告の表示時刻を共有の調停役へ記録する
        copyCount = 0
        coordinator.markPresented()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Self.logger.error(
            "InterstitialAd failed to present: \(error.localizedDescription, privacy: .public)"
        )
        coordinator.markPresentFailed()
        // 表示に失敗した広告は再利用できないため捨てて取り直す
        discardAd()
        Task { await loadAd() }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        coordinator.markDismissed()
        discardAd()
        Task { await loadAd() }
    }
}
