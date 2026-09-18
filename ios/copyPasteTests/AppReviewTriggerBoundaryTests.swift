import XCTest
@testable import ClipKit

/// レビュー事前確認の発火条件を**境界値で固定する**テスト（issue #105）。
///
/// #105 の本質は「条件が1つでもズレるとシートが永久に出なくなる」こと。
/// 実機で空振りしても気づけないため、しきい値・スロットル・使い切りの
/// 境界をここで数値ごと固定し、定数を触ったら必ずテストが落ちるようにする。
///
/// 判定は `AppReview.decide` を使い、出ない場合は「なぜ出ないか」まで突き合わせる。
/// Bool だけ見ていると、意図と違う理由でたまたま false になっていても気づけない。
final class AppReviewTriggerBoundaryTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    /// テスト内の「現在時刻」。日付境界の揺れを避けるため固定値を使う
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "AppReviewTriggerBoundaryTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        AppReview.resetProcessStateForTesting()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        AppReview.resetProcessStateForTesting()
        super.tearDown()
    }

    private func decide(
        _ trigger: AppReview.Trigger,
        launchCount: Int = 0,
        copyCount: Int = 0,
        isForeground: Bool = true,
        now: Date? = nil
    ) -> AppReview.Decision {
        AppReview.decide(
            trigger: trigger,
            launchCount: launchCount,
            copyCount: copyCount,
            isForeground: isForeground,
            defaults: defaults,
            now: now ?? self.now
        )
    }

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
    }

    // MARK: - 設定値そのものの固定

    /// 定数を変えたらこのテストが落ちる。以下の境界テストは全てこの値が前提。
    func testConfigValues() {
        XCTAssertEqual(AppReview.Config.launchTrigger, 2, "初回トリガーは「2回目の起動」")
        XCTAssertEqual(AppReview.Config.copyInterval, 10, "コピー10回ごと")
        XCTAssertEqual(AppReview.Config.minimumDaysBetweenPrompts, 30, "前回表示から30日")
    }

    // MARK: - 起動回数の境界（launchTrigger = 2）

    func testLaunchTriggerBoundary() {
        XCTAssertEqual(
            decide(.launch, launchCount: 0), .skip(.launchCountBelowThreshold),
            "0回目（AppDelegateを通っていない）では出さない"
        )
        XCTAssertEqual(
            decide(.launch, launchCount: 1), .skip(.launchCountBelowThreshold),
            "初回起動では出さない。ここが壊れると新規ユーザー全員に初回から出る"
        )
        XCTAssertEqual(
            decide(.launch, launchCount: 2), .prompt,
            "しきい値ちょうど（2回目の起動）で出す"
        )
        XCTAssertEqual(
            decide(.launch, launchCount: 3), .prompt,
            "しきい値を1つ超えても出す（等値比較に戻すとここが落ちる）"
        )
        XCTAssertEqual(
            decide(.launch, launchCount: 100), .prompt,
            "大きく飛んだユーザーも取りこぼさない"
        )
    }

    // MARK: - スロットルの境界（minimumDaysBetweenPrompts = 30）

    func testThrottleBoundary() {
        for days in [0, 1, 29] {
            defaults.set(daysAgo(days), forKey: "clipkit.lastReviewPromptDate")
            XCTAssertEqual(
                decide(.proPurchase), .skip(.throttled),
                "前回表示から\(days)日では見送ること（30日未満）"
            )
        }

        for days in [30, 31, 365] {
            defaults.set(daysAgo(days), forKey: "clipkit.lastReviewPromptDate")
            XCTAssertEqual(
                decide(.proPurchase), .prompt,
                "前回表示から\(days)日経っていれば出すこと（30日以上）"
            )
        }
    }

    func testThrottle_noRecordMeansNotThrottled() {
        XCTAssertFalse(
            AppReview.isThrottled(minimumDays: 30, defaults: defaults, now: now),
            "一度も表示していないユーザーはスロットルされないこと"
        )
    }

    /// 時計の巻き戻し／バックアップ復元で `lastReviewPromptDate` が未来になると、
    /// 素朴な `days < 30` 比較では永久にスロットルされ二度と出せなくなる。
    func testThrottle_futureDateDoesNotLockOutForever() {
        let farFuture = Calendar.current.date(byAdding: .day, value: 365, to: now) ?? now
        defaults.set(farFuture, forKey: "clipkit.lastReviewPromptDate")
        XCTAssertEqual(
            decide(.proPurchase), .prompt,
            "窓を超える未来日付は壊れた値とみなして無視すること（永久ロックアウト防止）"
        )

        let nearFuture = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        defaults.set(nearFuture, forKey: "clipkit.lastReviewPromptDate")
        XCTAssertEqual(
            decide(.proPurchase), .skip(.throttled),
            "数日ぶんの軽微なズレではスロットルを効かせたままにすること"
        )
    }

    // MARK: - コピーマイルストーンの境界（copyInterval = 10）

    func testCopyMilestoneBoundary() {
        for count in [0, 1, 9, 11, 19] {
            XCTAssertEqual(
                decide(.copyMilestone, copyCount: count), .skip(.copyCountNotAtMilestone),
                "コピー\(count)回では出さないこと"
            )
        }

        for count in [10, 20, 100] {
            XCTAssertEqual(
                decide(.copyMilestone, copyCount: count), .prompt,
                "コピー\(count)回（10の倍数）では出すこと"
            )
        }
    }

    /// copyCount = 0 は「10の倍数」だが、まだ一度もコピーしていないので出してはいけない。
    func testCopyMilestone_zeroIsNotAMilestone() {
        XCTAssertEqual(decide(.copyMilestone, copyCount: 0), .skip(.copyCountNotAtMilestone))
    }

    // MARK: - 使い切り・打ち切り条件

    func testLaunchTriggerIsConsumedOnlyOnce() {
        XCTAssertEqual(decide(.launch, launchCount: 2), .prompt)

        AppReview.markShown(trigger: .launch, defaults: defaults, now: now)

        // スロットルの影響を外して、使い切りフラグ単体の効果を見る
        let later = Calendar.current.date(byAdding: .day, value: 400, to: now) ?? now
        XCTAssertEqual(
            decide(.launch, launchCount: 5, now: later), .skip(.launchTriggerConsumed),
            "launchトリガーは一度出したら二度と使わないこと（毎起動出さない）"
        )
        XCTAssertEqual(
            decide(.copyMilestone, copyCount: 10, now: later), .prompt,
            "launchの使い切りは他のトリガーを止めないこと"
        )
    }

    func testAnsweredPositively_stopsEveryTrigger() {
        AppReview.markAnsweredPositively(defaults: defaults)

        XCTAssertEqual(decide(.launch, launchCount: 2), .skip(.answeredPositively))
        XCTAssertEqual(decide(.copyMilestone, copyCount: 10), .skip(.answeredPositively))
        XCTAssertEqual(decide(.proPurchase), .skip(.answeredPositively))
    }

    // MARK: - 見送り理由の優先順位

    /// 「出せない状況」の判定が最優先であること。
    /// ここが逆転すると、画面に出ていないのに条件だけ消費される（旧実装の事故）。
    func testNotForegroundTakesPrecedenceOverEverything() {
        XCTAssertEqual(
            decide(.launch, launchCount: 2, isForeground: false), .skip(.notForeground)
        )
        XCTAssertEqual(
            decide(.proPurchase, isForeground: false), .skip(.notForeground),
            "無条件で出すproPurchaseでも、画面に出せないなら見送ること"
        )
    }

    /// 見送った場合は何も記録しない＝次の機会に持ち越されること。
    func testSkipDoesNotRecordAnything() {
        _ = decide(.launch, launchCount: 2, isForeground: false)

        XCTAssertNil(
            defaults.object(forKey: "clipkit.lastReviewPromptDate"),
            "見送りで表示日時が記録されてはならない"
        )
        XCTAssertFalse(
            defaults.bool(forKey: "clipkit.launchTriggerConsumed"),
            "見送りでlaunchトリガーが消費されてはならない"
        )
        XCTAssertEqual(defaults.integer(forKey: "clipkit.reviewPromptCount"), 0)
    }

    /// 表示した時だけ記録されること（markShownは実表示時にViewから呼ばれる）。
    func testMarkShownRecordsPromptCountAndDate() {
        AppReview.markShown(trigger: .launch, defaults: defaults, now: now)

        XCTAssertEqual(defaults.integer(forKey: "clipkit.reviewPromptCount"), 1)
        XCTAssertEqual(defaults.object(forKey: "clipkit.lastReviewPromptDate") as? Date, now)
        XCTAssertTrue(defaults.bool(forKey: "clipkit.launchTriggerConsumed"))
    }

    // MARK: - shouldPrompt と decide が食い違わないこと

    /// `shouldPrompt` は `decide` の薄いラッパ。両者がズレると
    /// ログに出る理由と実際の挙動が食い違い、#105 の再来になる。
    private struct Scenario {
        let trigger: AppReview.Trigger
        let launchCount: Int
        let copyCount: Int
        let isForeground: Bool
    }

    func testShouldPromptMatchesDecide() {
        let scenarios = [
            Scenario(trigger: .launch, launchCount: 1, copyCount: 0, isForeground: true),
            Scenario(trigger: .launch, launchCount: 2, copyCount: 0, isForeground: true),
            Scenario(trigger: .launch, launchCount: 2, copyCount: 0, isForeground: false),
            Scenario(trigger: .copyMilestone, launchCount: 0, copyCount: 9, isForeground: true),
            Scenario(trigger: .copyMilestone, launchCount: 0, copyCount: 10, isForeground: true),
            Scenario(trigger: .proPurchase, launchCount: 0, copyCount: 0, isForeground: true)
        ]

        for scenario in scenarios {
            let expected = decide(
                scenario.trigger,
                launchCount: scenario.launchCount,
                copyCount: scenario.copyCount,
                isForeground: scenario.isForeground
            ).shouldPrompt
            let actual = AppReview.shouldPrompt(
                trigger: scenario.trigger,
                launchCount: scenario.launchCount,
                copyCount: scenario.copyCount,
                isForeground: scenario.isForeground,
                defaults: defaults,
                now: now
            )
            XCTAssertEqual(
                actual, expected,
                """
                shouldPromptとdecideが一致すること \
                (trigger=\(scenario.trigger.rawValue) launch=\(scenario.launchCount) \
                copy=\(scenario.copyCount) fg=\(scenario.isForeground))
                """
            )
        }
    }
}
