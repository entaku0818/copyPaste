import XCTest
@testable import ClipKit

/// 起動回数トリガーの回帰テスト（issue #105）。
///
/// 実機で観測された不具合: クリーンインストール後の**1回目の起動**で
/// レビュー事前確認モーダルが表示されていた。
/// 原因は `.onAppear` 起点で起動回数を数えていたことによる二重計上で、
/// 1回の起動で launchCount が 2 になり `launchCount == launchTrigger(2)` が
/// 初回で成立していた。「初回は聞かない」という設計意図が壊れていた。
final class AppReviewLaunchTriggerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        // 実UserDefaultsを汚さないよう専用スイートを使う
        suiteName = "AppReviewLaunchTriggerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        AppReview.resetProcessStateForTesting()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        AppReview.resetProcessStateForTesting()
        super.tearDown()
    }

    // MARK: - 二重計上の防止

    func testIncrementLaunchCount_countsOncePerProcessEvenIfCalledTwice() {
        let first = AppReview.incrementLaunchCount(defaults: defaults)
        let second = AppReview.incrementLaunchCount(defaults: defaults)

        XCTAssertEqual(first, 1, "1回目の起動では1になること")
        XCTAssertEqual(
            second, 1,
            "同じプロセス内で2回呼ばれても増えないこと（onAppearが複数回来ても二重計上しない）"
        )
        XCTAssertEqual(AppReview.launchCount(defaults: defaults), 1)
    }

    func testLaunchCount_doesNotIncrement() {
        AppReview.incrementLaunchCount(defaults: defaults)
        _ = AppReview.launchCount(defaults: defaults)
        _ = AppReview.launchCount(defaults: defaults)

        XCTAssertEqual(
            AppReview.launchCount(defaults: defaults), 1,
            "読み取り用のlaunchCountは値を変えないこと"
        )
    }

    // MARK: - 発火タイミング

    func testShouldPrompt_doesNotFireOnFirstLaunch() {
        let count = AppReview.incrementLaunchCount(defaults: defaults)

        XCTAssertFalse(
            AppReview.shouldPrompt(
                trigger: .launch, launchCount: count,
                isForeground: true, defaults: defaults
            ),
            "初回起動では事前確認を出さないこと（これが壊れていた）"
        )
    }

    func testShouldPrompt_firesOnSecondLaunch() {
        // 1回目
        AppReview.incrementLaunchCount(defaults: defaults)
        // 2回目（別プロセス相当）
        AppReview.resetProcessStateForTesting()
        let count = AppReview.incrementLaunchCount(defaults: defaults)

        XCTAssertEqual(count, 2)
        XCTAssertTrue(
            AppReview.shouldPrompt(
                trigger: .launch, launchCount: count,
                isForeground: true, defaults: defaults
            ),
            "2回目の起動では出すこと"
        )
    }

    /// 等値比較(== 2)だとカウントが飛んだユーザーは二度と当たらなくなる。
    /// しきい値以上に変えたことで取りこぼさないことを確認する。
    func testShouldPrompt_stillFiresWhenLaunchCountSkippedPastThreshold() {
        XCTAssertTrue(
            AppReview.shouldPrompt(
                trigger: .launch, launchCount: 7,
                isForeground: true, defaults: defaults
            ),
            "しきい値を超えて到達したユーザーにも出すこと"
        )
    }

    // MARK: - 使い切り

    func testShouldPrompt_launchTriggerIsConsumedAfterShown() {
        XCTAssertTrue(
            AppReview.shouldPrompt(
                trigger: .launch, launchCount: 2,
                isForeground: true, defaults: defaults
            )
        )

        AppReview.markShown(trigger: .launch, defaults: defaults)

        // スロットルの影響を除くため、31日後を現在時刻として判定する
        let later = Date().addingTimeInterval(60 * 60 * 24 * 31)
        XCTAssertFalse(
            AppReview.shouldPrompt(
                trigger: .launch, launchCount: 9,
                isForeground: true, defaults: defaults, now: later
            ),
            "launchトリガーは一度出したら使い切られること（毎起動出さない）"
        )
    }

    func testMarkShown_copyMilestoneDoesNotConsumeLaunchTrigger() {
        AppReview.markShown(trigger: .copyMilestone, defaults: defaults)

        let later = Date().addingTimeInterval(60 * 60 * 24 * 31)
        XCTAssertTrue(
            AppReview.shouldPrompt(
                trigger: .launch, launchCount: 2,
                isForeground: true, defaults: defaults, now: later
            ),
            "copyMilestoneでの表示はlaunchトリガーを消費しないこと"
        )
    }

    // MARK: - 既存の見送り条件が壊れていないこと

    func testShouldPrompt_neverFiresWhileBackgroundedOrInPiP() {
        XCTAssertFalse(
            AppReview.shouldPrompt(
                trigger: .launch, launchCount: 2,
                isForeground: false, defaults: defaults
            ),
            "フォアグラウンドでないときは判定自体を行わないこと"
        )
    }
}
