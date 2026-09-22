//
//  AppReview.swift
//  ClipKit
//
//  レビュー依頼まわりの発火条件・頻度制御・記録を一箇所に集約する。
//  「満足していますか？」という事前確認シートを経てから
//  AppStore.requestReview を呼ぶ2段階フローを維持し、
//  「不満」を選んだユーザーはFeedbackFormViewに誘導する。
//
//  旧実装（captureCountの5/20/50マイルストーン）は .addItem =
//  クリップボードの自動キャプチャから発火していたため、PiPでの
//  バックグラウンド監視中にマイルストーンだけが消費され、シートが
//  一度も表示されないまま二度と出なくなる問題があった。
//  そのため以下2点を設計で担保する:
//    1. 発火判定は必ずフォアグラウンドのユーザー操作を起点にする
//    2. 「表示した」記録は実際にシートが画面に出た時点で行う（markShown）
//

import Foundation
import OSLog
import StoreKit
import UIKit
import FirebaseAnalytics

enum AppReview {
    /// レビュー依頼の発火条件を定数として集約したもの。
    ///
    /// Appleはシステムのレビューダイアログを年3回までしか実際に表示しない
    /// （アプリ側では検知・制御できない仕様のため、それ自体をここで再実装する必要はない）。
    /// アプリ側の役割は「ポジティブ体験の直後」に事前確認を出すタイミングを選ぶことと、
    /// 同じユーザーに何度も事前確認シートを見せすぎないよう独自に間隔を空けることの2点。
    enum Config {
        /// 何回目の起動で初回の事前確認を検討するか。
        /// 起動イベントは必ずフォアグラウンドで起きるため、バックグラウンド発火で
        /// 条件が焼き切れる心配がない。
        static let launchTrigger = 2

        /// 履歴からコピー（＝時短が成立した瞬間）が何回ごとに事前確認を検討するか。
        /// 初回起動トリガーを逃した／スロットル中だったユーザーの受け皿になる。
        static let copyInterval = 10

        /// 全トリガー共通の頻度制御: 前回の事前確認表示から最低何日空けるか。
        /// これがないとヘビーユーザーほど短期間に何度も同じシートを見ることになる。
        static let minimumDaysBetweenPrompts = 30

        /// 「満足している」を押してから `AppStore.requestReview` を呼ぶまでの待ち時間。
        ///
        /// 事前確認オーバーレイは `.easeInOut(duration: 0.2)` で閉じるため、
        /// 押した直後に呼ぶと**画面遷移の最中に requestReview を呼ぶ**ことになり、
        /// OSがダイアログを無言で握り潰す（issue #106）。
        /// オーバーレイが消えきってから呼ぶために余裕を持って待つ。
        static let systemDialogDelay: Duration = .milliseconds(600)
    }

    /// どのトリガーで事前確認が出たかを識別する。Analyticsのパラメータにも使う。
    enum Trigger: String, Equatable, Sendable {
        /// 2回目の起動
        case launch = "launch"
        /// 履歴からのコピーがcopyIntervalの倍数に到達
        case copyMilestone = "copy_milestone"
        /// Proへのアップグレードが成立
        case proPurchase = "pro_purchase"
    }

    /// 事前確認を見送った理由。ログとAnalyticsに出して「なぜ出なかったか」を
    /// 実機のログだけで切り分けられるようにする（issue #105）。
    enum SkipReason: String, Equatable, Sendable {
        /// バックグラウンドまたはPiP中で、そもそも画面に出せない
        case notForeground = "not_foreground"
        /// すでに「満足」と答えている
        case answeredPositively = "answered_positively"
        /// 前回表示から minimumDaysBetweenPrompts 日経っていない
        case throttled = "throttled"
        /// launchトリガーは一度出して使い切っている
        case launchTriggerConsumed = "launch_trigger_consumed"
        /// 起動回数がまだ launchTrigger に届いていない
        case launchCountBelowThreshold = "launch_count_below_threshold"
        /// コピー回数が copyInterval の倍数に達していない
        case copyCountNotAtMilestone = "copy_count_not_at_milestone"
    }

    /// 発火判定の結果。Boolだけだと「出なかった理由」が消えるため、
    /// 理由まで含めて返す（`shouldPrompt` はこれを畳んだ薄いラッパ）。
    enum Decision: Equatable, Sendable {
        case prompt
        case skip(SkipReason)

        var shouldPrompt: Bool { self == .prompt }
    }

    private static let logger = Logger(subsystem: "com.entaku.clipkit", category: "AppReview")

    private enum Key {
        static let launchCount = "clipkit.launchCount"
        static let lastPromptDate = "clipkit.lastReviewPromptDate"
        static let promptCount = "clipkit.reviewPromptCount"
        static let answeredPositively = "clipkit.hasAnsweredReviewPositively"
        /// launchトリガーを一度使い切ったか（issue #105）
        static let launchTriggerConsumed = "clipkit.launchTriggerConsumed"
    }

    /// ClipKitのApp Store ID（`?action=write-review` ディープリンク用）
    static let appStoreID = "6759832862"

    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    // MARK: - 起動回数

    /// 起動回数をインクリメントして新しい値を返す。
    ///
    /// **1プロセスにつき必ず1回だけ**呼ぶ必要がある。
    /// 以前はViewの `.onAppear` を起点に呼んでおり、TabViewが複数のタブの
    /// `onAppear` を発火させる（MonitoringViewとClipboardHistoryViewの2箇所が
    /// `.onAppear` を送る）ため、1回の起動で2回カウントされていた（issue #105）。
    /// その結果 `launchCount == launchTrigger(2)` が**初回起動で成立**し、
    /// 「初回は聞かない」という設計意図が壊れていた。
    ///
    /// 呼び出し箇所をプロセス起動時（AppDelegate）に移したうえで、
    /// ここでもstaticフラグで二重呼び出しを防ぐ二重の安全弁を置く。
    private static let incrementLock = NSLock()
    private static var hasIncrementedThisProcess = false

    @discardableResult
    static func incrementLaunchCount(defaults: UserDefaults = .standard) -> Int {
        incrementLock.lock()
        defer { incrementLock.unlock() }
        let current = defaults.integer(forKey: Key.launchCount)
        guard !hasIncrementedThisProcess else {
            // ここに来る＝1プロセス内で2回目以降の呼び出し。二重計上を握り潰した記録を残す。
            logger.error("launchCount: 同一プロセス内で2回目のincrementを抑止した (count=\(current, privacy: .public))")
            return current
        }
        hasIncrementedThisProcess = true
        let next = current + 1
        defaults.set(next, forKey: Key.launchCount)
        logger.info("launchCount: \(current, privacy: .public) -> \(next, privacy: .public)")
        return next
    }

    /// 記録済みの起動回数を読むだけ（インクリメントしない）
    static func launchCount(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: Key.launchCount)
    }

    /// テスト用: プロセス内の二重呼び出し防止フラグを戻す
    static func resetProcessStateForTesting() {
        incrementLock.lock()
        defer { incrementLock.unlock() }
        hasIncrementedThisProcess = false
    }

    // MARK: - 発火判定

    /// 指定トリガーで事前確認シートを出してよいか判定する。
    ///
    /// - Parameters:
    ///   - trigger: 発火元
    ///   - launchCount: `.launch` の判定に使う起動回数（インクリメント済みの最新値）
    ///   - copyCount: `.copyMilestone` の判定に使うコピー回数（インクリメント済みの最新値）
    ///   - isForeground: アプリがフォアグラウンドかつPiP中でないか。falseなら常に見送る
    static func shouldPrompt(
        trigger: Trigger,
        launchCount: Int = 0,
        copyCount: Int = 0,
        isForeground: Bool,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> Bool {
        decide(
            trigger: trigger,
            launchCount: launchCount,
            copyCount: copyCount,
            isForeground: isForeground,
            defaults: defaults,
            now: now
        ).shouldPrompt
    }

    /// `shouldPrompt` の本体。出す／出さないに加えて「出さない理由」を返す。
    ///
    /// #105 の調査で一番困ったのが「シートが出ない」という結果だけが観測でき、
    /// どの条件で落ちたのかが実機ログから分からなかったこと。
    /// 判定結果は必ずここで os_log に出すので、以後は
    /// `xcrun simctl spawn <udid> log stream --predicate 'category == "AppReview"'`
    /// だけで空振りの原因を切り分けられる。
    static func decide(
        trigger: Trigger,
        launchCount: Int = 0,
        copyCount: Int = 0,
        isForeground: Bool,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> Decision {
        let decision = Self.evaluate(
            trigger: trigger,
            launchCount: launchCount,
            copyCount: copyCount,
            context: Context(isForeground: isForeground, defaults: defaults, now: now)
        )
        let outcome: String
        switch decision {
        case .prompt:
            outcome = "出す"
        case let .skip(reason):
            outcome = "見送り reason=\(reason.rawValue)"
        }
        let message = "decide(\(trigger.rawValue)): \(outcome)"
            + " launchCount=\(launchCount) copyCount=\(copyCount)"
        logger.info("\(message, privacy: .public)")
        return decision
    }

    /// 判定に必要な「トリガー以外の状況」をまとめたもの
    private struct Context {
        let isForeground: Bool
        let defaults: UserDefaults
        let now: Date
    }

    private static func evaluate(
        trigger: Trigger,
        launchCount: Int,
        copyCount: Int,
        context: Context
    ) -> Decision {
        let defaults = context.defaults

        // 画面に出せない状況では判定自体を行わない。
        // ここで見送っても何も記録しないので、次の機会にそのまま持ち越される。
        guard context.isForeground else { return .skip(.notForeground) }

        // 一度「満足」と答えた人には二度と出さない
        guard !defaults.bool(forKey: Key.answeredPositively) else { return .skip(.answeredPositively) }

        // 全トリガー共通のスロットル
        guard !isThrottled(
            minimumDays: Config.minimumDaysBetweenPrompts,
            defaults: defaults,
            now: context.now
        ) else { return .skip(.throttled) }

        switch trigger {
        case .launch:
            // 等値比較(== 2)だと、何らかの理由でカウントが飛んだユーザーは
            // 二度とこのトリガーに当たらなくなる（issue #105 で実際に起きた）。
            // 「しきい値以上」かつ「まだ一度も使っていない」に変える。
            guard !defaults.bool(forKey: Key.launchTriggerConsumed) else {
                return .skip(.launchTriggerConsumed)
            }
            guard launchCount >= Config.launchTrigger else {
                return .skip(.launchCountBelowThreshold)
            }
            return .prompt
        case .copyMilestone:
            guard copyCount > 0, copyCount % Config.copyInterval == 0 else {
                return .skip(.copyCountNotAtMilestone)
            }
            return .prompt
        case .proPurchase:
            return .prompt
        }
    }

    /// 前回の表示から指定日数以上経っていなければtrue（頻度制御）
    static func isThrottled(
        minimumDays: Int,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> Bool {
        guard let lastDate = defaults.object(forKey: Key.lastPromptDate) as? Date else {
            return false
        }
        let days = Calendar.current.dateComponents([.day], from: lastDate, to: now).day ?? 0
        // 端末の時計が巻き戻された／バックアップ復元で未来の日付が入った場合、
        // days は負になる。素直に `days < minimumDays` と比べると永久にtrue＝
        // 二度と事前確認を出せない状態に固定されてしまう。
        // 窓を超える未来日付は値そのものが壊れているとみなして無視する
        // （数日ぶんの軽微なズレはそのままスロットルを効かせる）。
        return abs(days) < minimumDays
    }

    // MARK: - 記録

    /// 事前確認シートが実際に画面に出た時点で呼ぶ。
    /// 判定時ではなく表示時に記録することで、表示されないまま条件が
    /// 消費されてしまう事故を防ぐ。
    static func markShown(
        trigger: Trigger,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        defaults.set(defaults.integer(forKey: Key.promptCount) + 1, forKey: Key.promptCount)
        defaults.set(now, forKey: Key.lastPromptDate)
        // launchトリガーは一度出したら使い切る（issue #105）
        if trigger == .launch {
            defaults.set(true, forKey: Key.launchTriggerConsumed)
        }
        let promptCount = defaults.integer(forKey: Key.promptCount)
        let message = "markShown(\(trigger.rawValue)): シートが画面に出た (promptCount=\(promptCount))"
        logger.info("\(message, privacy: .public)")
        Analytics.logEvent("review_request_shown", parameters: ["trigger": trigger.rawValue])
    }

    /// 「満足」が選ばれた際に呼ぶ。以降このユーザーには事前確認を出さない。
    static func markAnsweredPositively(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Key.answeredPositively)
        Analytics.logEvent("review_request_accepted", parameters: nil)
    }

    /// 「不満」が選ばれた際に呼ぶ。フィードバックフォームへの誘導は呼び出し側の責務。
    static func markAnsweredNegatively() {
        Analytics.logEvent("review_request_declined", parameters: nil)
    }

    // MARK: - システムダイアログ

    /// システムレビューダイアログの提示先シーンを選ぶ。
    ///
    /// **型で絞ってから状態で探すこと。** 旧実装は
    /// `.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene`
    /// と書いていたが、`connectedScenes` は `Set<UIScene>` で順序が不定なため、
    /// foregroundActive なシーンが複数あって先に引いたものが `UIWindowScene` でないと
    /// キャストに失敗して nil になり、**ダイアログを出さずに無言終了**していた。
    /// ClipKitはPiPを使うのでシーンが複数ある場面があり、実際に
    /// 「満足している」を押した81人に対して評価が2件しか付いていなかった（issue #106）。
    static func presentationScene(from scenes: [UIScene]) -> UIWindowScene? {
        scenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    /// 実際のシステムレビューダイアログを呼び出す。
    ///
    /// 呼べた／呼べなかったを必ず記録する。#106 の調査で困ったのが
    /// 「`review_request_accepted` の後に何が起きたか分からない」ことだったため、
    /// シーンが取れずに見送ったケースを区別してログとAnalyticsに残す。
    /// なお `AppStore.requestReview` 自体は呼んでも実際に表示されるとは限らない
    /// （Appleが年3回までに制限しており、アプリ側からは検知できない）。
    @MainActor
    @discardableResult
    static func requestSystemReview() -> Bool {
        guard let scene = presentationScene(from: Array(UIApplication.shared.connectedScenes)) else {
            logger.error("requestSystemReview: foregroundActiveなUIWindowSceneが無く呼び出せなかった")
            Analytics.logEvent(
                "review_system_dialog_skipped",
                parameters: ["reason": "no_foreground_window_scene"]
            )
            return false
        }
        AppStore.requestReview(in: scene)
        logger.info("requestSystemReview: AppStore.requestReview を呼び出した")
        Analytics.logEvent("review_system_dialog_requested", parameters: nil)
        return true
    }

    /// App Storeのレビュー投稿画面を直接開く。
    /// 「レビューを書く」のように明示的な意思で来たユーザーに対しては、
    /// Appleが表示を握り潰す可能性のあるシステムダイアログではなくこちらを使う。
    @MainActor
    static func openWriteReviewPage() {
        guard let url = writeReviewURL else { return }
        Analytics.logEvent("write_review_tapped", parameters: nil)
        UIApplication.shared.open(url)
    }
}
