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
}
