import XCTest
import UIKit
@testable import ClipKit

/// レビュー事前確認の発火条件を**境界値で固定する**テスト（issue #105）。
///
/// #105 の本質は「条件が1つでもズレるとシートが永久に出なくなる」こと。
/// 実機で空振りしても気づけないため、しきい値・スロットルの
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
        isForeground: Bool = true,
        now: Date? = nil
    ) -> AppReview.Decision {
        AppReview.decide(
            trigger: trigger,
            launchCount: launchCount,
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
        XCTAssertEqual(AppReview.Config.launchTrigger, 2, "トリガーは「2回目以降の起動」")
        XCTAssertEqual(AppReview.Config.minimumDaysBetweenPrompts, 90, "前回表示から90日")
    }

    /// コピー10回ごと（copy_milestone）とPro購入直後（pro_purchase）は廃止した。
    /// トリガーを足したらここが落ちる＝仕様変更として意識して足すこと。
    func testOnlyLaunchTriggerExists() {
        XCTAssertEqual(AppReview.Trigger.allCases, [.launch])
        XCTAssertEqual(AppReview.Trigger.launch.rawValue, "launch", "Analyticsのtrigger値")
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

    // MARK: - スロットルの境界（minimumDaysBetweenPrompts = 90）

    func testThrottleBoundary() {
        for days in [0, 1, 30, 89] {
            defaults.set(daysAgo(days), forKey: "clipkit.lastReviewPromptDate")
            XCTAssertEqual(
                decide(.launch, launchCount: 3), .skip(.throttled),
                "前回表示から\(days)日では見送ること（90日未満）"
            )
        }

        for days in [90, 91, 365] {
            defaults.set(daysAgo(days), forKey: "clipkit.lastReviewPromptDate")
            XCTAssertEqual(
                decide(.launch, launchCount: 3), .prompt,
                "前回表示から\(days)日経っていれば出すこと（90日以上）"
            )
        }
    }

    func testThrottle_noRecordMeansNotThrottled() {
        XCTAssertFalse(
            AppReview.isThrottled(minimumDays: 90, defaults: defaults, now: now),
            "一度も表示していないユーザーはスロットルされないこと"
        )
    }

    /// 時計の巻き戻し／バックアップ復元で `lastReviewPromptDate` が未来になると、
    /// 素朴な `days < 90` 比較では永久にスロットルされ二度と出せなくなる。
    func testThrottle_futureDateDoesNotLockOutForever() {
        let farFuture = Calendar.current.date(byAdding: .day, value: 365, to: now) ?? now
        defaults.set(farFuture, forKey: "clipkit.lastReviewPromptDate")
        XCTAssertEqual(
            decide(.launch, launchCount: 3), .prompt,
            "窓を超える未来日付は壊れた値とみなして無視すること（永久ロックアウト防止）"
        )

        let nearFuture = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        defaults.set(nearFuture, forKey: "clipkit.lastReviewPromptDate")
        XCTAssertEqual(
            decide(.launch, launchCount: 3), .skip(.throttled),
            "数日ぶんの軽微なズレではスロットルを効かせたままにすること"
        )
    }

    // MARK: - 繰り返し・打ち切り条件（ナレーター方式）

    /// launchトリガーは使い切りではない。表示後は90日のスロットルだけで間引き、
    /// 明けた後の起動でまた出す。
    func testLaunchTriggerRepeatsAfterCooldown() {
        XCTAssertEqual(decide(.launch, launchCount: 2), .prompt)

        AppReview.markShown(trigger: .launch, defaults: defaults, now: now)

        let within = Calendar.current.date(byAdding: .day, value: 89, to: now) ?? now
        XCTAssertEqual(
            decide(.launch, launchCount: 5, now: within), .skip(.throttled),
            "90日以内の起動では出さないこと"
        )
        let after = Calendar.current.date(byAdding: .day, value: 90, to: now) ?? now
        XCTAssertEqual(
            decide(.launch, launchCount: 5, now: after), .prompt,
            "90日後の起動ではまた出すこと"
        )
    }

    /// 「満足」と答えた人も永久停止しない。90日空けば再び聞く（ナレーターと同じ）。
    func testAnsweredPositively_doesNotStopFuturePrompts() {
        AppReview.markShown(trigger: .launch, defaults: defaults, now: daysAgo(90))
        AppReview.markAnsweredPositively()
        // 旧実装で保存された「満足」フラグが残っている端末も同じ扱いにする
        defaults.set(true, forKey: "clipkit.hasAnsweredReviewPositively")

        XCTAssertEqual(decide(.launch, launchCount: 4), .prompt)
    }

    // MARK: - 見送り理由の優先順位

    /// 「出せない状況」の判定が最優先であること。
    /// ここが逆転すると、画面に出ていないのに条件だけ消費される（旧実装の事故）。
    func testNotForegroundTakesPrecedenceOverEverything() {
        XCTAssertEqual(
            decide(.launch, launchCount: 2, isForeground: false), .skip(.notForeground)
        )
        defaults.set(daysAgo(1), forKey: "clipkit.lastReviewPromptDate")
        XCTAssertEqual(
            decide(.launch, launchCount: 2, isForeground: false), .skip(.notForeground),
            "スロットル中でも、まず画面に出せないことを理由にすること"
        )
    }

    /// 見送った場合は何も記録しない＝次の機会に持ち越されること。
    func testSkipDoesNotRecordAnything() {
        _ = decide(.launch, launchCount: 2, isForeground: false)

        XCTAssertNil(
            defaults.object(forKey: "clipkit.lastReviewPromptDate"),
            "見送りで表示日時が記録されてはならない"
        )
        XCTAssertEqual(defaults.integer(forKey: "clipkit.reviewPromptCount"), 0)
    }

    /// 表示した時だけ記録されること（markShownは実表示時にViewから呼ばれる）。
    func testMarkShownRecordsPromptCountAndDate() {
        AppReview.markShown(trigger: .launch, defaults: defaults, now: now)

        XCTAssertEqual(defaults.integer(forKey: "clipkit.reviewPromptCount"), 1)
        XCTAssertEqual(defaults.object(forKey: "clipkit.lastReviewPromptDate") as? Date, now)
    }

    // MARK: - システムダイアログの提示先シーン（issue #106）

    /// 旧実装は
    /// `.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene`
    /// と書いていた。`connectedScenes` は `Set<UIScene>` で順序が不定なので、
    /// foregroundActive なシーンが複数あって先に引いたものが UIWindowScene でないと
    /// キャストに失敗して nil になり、ダイアログを出さずに無言終了していた。
    /// 「型で絞ってから状態で探す」ことを固定する。
    func testPresentationScene_findsForegroundWindowSceneFromRealScenes() {
        let scenes = Array(UIApplication.shared.connectedScenes)
        XCTAssertFalse(scenes.isEmpty, "テストホストアプリのシーンが取得できていること")

        let scene = AppReview.presentationScene(from: scenes)

        XCTAssertNotNil(
            scene,
            "foregroundActiveなUIWindowSceneがあるなら必ず見つけること（ここがnilだとダイアログが出ない）"
        )
        XCTAssertEqual(
            scene?.activationState, .foregroundActive,
            "foregroundActiveなシーンを返すこと"
        )
    }

    /// シーンの並び順に依存しないこと（`Set` の順序は不定なので順序に依存してはいけない）。
    func testPresentationScene_isOrderIndependent() {
        let scenes = Array(UIApplication.shared.connectedScenes)

        XCTAssertEqual(
            AppReview.presentationScene(from: scenes)?.activationState,
            AppReview.presentationScene(from: scenes.reversed())?.activationState,
            "並び順を変えても同じ状態のシーンを選ぶこと"
        )
    }

    /// 出せるシーンが無いときは nil を返す（呼び出し側がAnalyticsに記録する分岐）。
    func testPresentationScene_returnsNilWhenNoScenes() {
        XCTAssertNil(AppReview.presentationScene(from: []))
    }

    // MARK: - shouldPrompt と decide が食い違わないこと

    /// `shouldPrompt` は `decide` の薄いラッパ。両者がズレると
    /// ログに出る理由と実際の挙動が食い違い、#105 の再来になる。
    private struct Scenario {
        let trigger: AppReview.Trigger
        let launchCount: Int
        let isForeground: Bool
    }

    func testShouldPromptMatchesDecide() {
        let scenarios = [
            Scenario(trigger: .launch, launchCount: 0, isForeground: true),
            Scenario(trigger: .launch, launchCount: 1, isForeground: true),
            Scenario(trigger: .launch, launchCount: 2, isForeground: true),
            Scenario(trigger: .launch, launchCount: 2, isForeground: false),
            Scenario(trigger: .launch, launchCount: 50, isForeground: true)
        ]

        for scenario in scenarios {
            let expected = decide(
                scenario.trigger,
                launchCount: scenario.launchCount,
                isForeground: scenario.isForeground
            ).shouldPrompt
            let actual = AppReview.shouldPrompt(
                trigger: scenario.trigger,
                launchCount: scenario.launchCount,
                isForeground: scenario.isForeground,
                defaults: defaults,
                now: now
            )
            XCTAssertEqual(
                actual, expected,
                """
                shouldPromptとdecideが一致すること \
                (trigger=\(scenario.trigger.rawValue) launch=\(scenario.launchCount) \
                fg=\(scenario.isForeground))
                """
            )
        }
    }
}
