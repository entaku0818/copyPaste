import XCTest
@testable import ClipKit

/// 全画面広告（app_open / interstitial）の相互排他のテスト。
/// 起動直後のapp_openとタブ切替のinterstitialが2枚続けて出る事故を防げているかを見る。
@MainActor
final class FullScreenAdCoordinatorTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "FullScreenAdCoordinatorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeCoordinator() -> FullScreenAdCoordinator {
        FullScreenAdCoordinator(defaults: defaults)
    }

    func testCanPresent_whenNothingShownYet_returnsTrue() {
        let coordinator = makeCoordinator()
        XCTAssertTrue(coordinator.canPresent(minimumGap: 30 * 60))
    }

    func testCanPresent_whileAnotherAdIsOnScreen_returnsFalse() {
        let coordinator = makeCoordinator()
        coordinator.markPresentAttempt()
        XCTAssertFalse(
            coordinator.canPresent(minimumGap: 0),
            "別の全画面広告が出ている間は、間隔ゼロでも表示させないこと"
        )
    }

    func testCanPresent_immediatelyAfterAnotherAd_returnsFalse() {
        let coordinator = makeCoordinator()
        let now = Date()
        coordinator.markPresented(now: now)
        coordinator.markDismissed()

        XCTAssertFalse(
            coordinator.canPresent(minimumGap: 30 * 60, now: now.addingTimeInterval(1)),
            "app_openを閉じた直後にinterstitialが続けて出ないこと"
        )
    }

    func testCanPresent_afterMinimumGapElapsed_returnsTrue() {
        let coordinator = makeCoordinator()
        let now = Date()
        coordinator.markPresented(now: now)
        coordinator.markDismissed()

        XCTAssertTrue(
            coordinator.canPresent(minimumGap: 30 * 60, now: now.addingTimeInterval(30 * 60))
        )
    }

    func testMarkPresentFailed_doesNotBlockTheOtherFormat() {
        let coordinator = makeCoordinator()
        coordinator.markPresentAttempt()
        coordinator.markPresentFailed()

        XCTAssertNil(coordinator.lastPresentedAt, "出ていない広告は表示時刻を記録しないこと")
        XCTAssertTrue(
            coordinator.canPresent(minimumGap: 30 * 60),
            "表示に失敗しただけなら、もう一方のフォーマットまで巻き添えで塞がないこと"
        )
    }

    func testLastPresentedAt_isSharedAcrossFormats() {
        let now = Date()
        makeCoordinator().markPresented(now: now)

        // 別インスタンス＝別Managerから見ても同じ記録が見えること
        let other = makeCoordinator()
        XCTAssertEqual(other.lastPresentedAt, now)
        XCTAssertFalse(other.canPresent(minimumGap: 60, now: now.addingTimeInterval(10)))
    }
}
