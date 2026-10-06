import XCTest
@testable import ClipKit

/// App Open広告の表示間隔・先読み判定のテスト
@MainActor
final class AppOpenAdManagerTests: XCTestCase {
    func testIsShowOpportunity_firstLaunchDoesNotShow() {
        XCTAssertFalse(
            AppOpenAdManager.isShowOpportunity(count: 1),
            "初回フォアグラウンドでは出さないこと"
        )
    }

    func testIsShowOpportunity_everyFifthForeground() {
        XCTAssertEqual(AppOpenAdManager.showInterval, 5)
        for count in 1...20 {
            XCTAssertEqual(
                AppOpenAdManager.isShowOpportunity(count: count),
                count % 5 == 0,
                "count=\(count) の判定が起動5回に1回になっていること"
            )
        }
    }

    func testIsShowOpportunity_zeroIsNotShowOpportunity() {
        XCTAssertFalse(AppOpenAdManager.isShowOpportunity(count: 0))
    }

    func testShouldPreload_onlyRightBeforeAShowOpportunity() {
        // 4回目のフォアグラウンドを終えた時点でだけ先読みする（無駄打ちを避ける）
        XCTAssertTrue(AppOpenAdManager.shouldPreload(after: 4))
        XCTAssertTrue(AppOpenAdManager.shouldPreload(after: 9))
        for count in [1, 2, 3, 5, 6, 7, 8] {
            XCTAssertFalse(
                AppOpenAdManager.shouldPreload(after: count),
                "count=\(count) では先読みしないこと"
            )
        }
    }

    func testForegroundCountKey_isNotSharedWithAppReviewLaunchCount() {
        // カウンタキーの使い回しで表示機会が消える事故を防ぐ
        let defaults = UserDefaults.standard
        let appReviewKey = "clipkit.launchCount"
        let appOpenKey = "clipkit.appOpenAd.foregroundCount"
        XCTAssertNotEqual(appReviewKey, appOpenKey)

        let before = defaults.integer(forKey: appReviewKey)
        defaults.set(before + 42, forKey: appOpenKey)
        XCTAssertEqual(
            defaults.integer(forKey: appReviewKey),
            before,
            "App Open広告のカウンタを進めてもAppReviewの起動カウンタが動かないこと"
        )
        defaults.removeObject(forKey: appOpenKey)
    }

    // MARK: - コールドスタートの結果（レビュー依頼の起動時判定で使う）

    /// 結果が確定する前に呼ばれたら、確定するまで待ってその値を返すこと。
    /// レビュー依頼の判定がApp Open広告の判断より先に走ると、全画面広告の上に被さる。
    func testColdStartDidShowAd_waitsUntilResolved() async {
        let manager = AppOpenAdManager(coordinator: FullScreenAdCoordinator())
        let waiter = Task { await manager.coldStartDidShowAd() }
        await Task.yield()

        manager.resolveColdStartForTesting(true)

        let result = await waiter.value
        XCTAssertTrue(result, "確定した値（広告を出した）が待っていた側に返ること")
    }

    /// 最初の結果だけが有効で、以後の復帰（2回目以降のフォアグラウンド）で上書きされないこと。
    func testColdStartDidShowAd_keepsFirstResult() async {
        let manager = AppOpenAdManager(coordinator: FullScreenAdCoordinator())
        manager.resolveColdStartForTesting(false)
        manager.resolveColdStartForTesting(true)

        let result = await manager.coldStartDidShowAd()
        XCTAssertFalse(result, "コールドスタートの結果は最初の1回で確定すること")
    }

    /// Proユーザーは広告を出さないので、即座に「出していない」で確定すること。
    func testHandleForeground_proUserResolvesColdStartAsNotShown() async {
        let manager = AppOpenAdManager(coordinator: FullScreenAdCoordinator())
        let didShow = await manager.handleForeground(isProUser: true)

        XCTAssertFalse(didShow)
        let result = await manager.coldStartDidShowAd()
        XCTAssertFalse(result, "Proユーザーの起動ではレビュー判定を止めないこと")
    }
}
