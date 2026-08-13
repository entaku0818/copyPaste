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
        guard !hasIncrementedThisProcess else {
            return defaults.integer(forKey: Key.launchCount)
        }
        hasIncrementedThisProcess = true
        let next = defaults.integer(forKey: Key.launchCount) + 1
        defaults.set(next, forKey: Key.launchCount)
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
        // 画面に出せない状況では判定自体を行わない。
        // ここで見送っても何も記録しないので、次の機会にそのまま持ち越される。
        guard isForeground else { return false }

        // 一度「満足」と答えた人には二度と出さない
        guard !defaults.bool(forKey: Key.answeredPositively) else { return false }

        // 全トリガー共通のスロットル
        guard !isThrottled(
            minimumDays: Config.minimumDaysBetweenPrompts,
            defaults: defaults,
            now: now
        ) else { return false }

        switch trigger {
        case .launch:
            // 等値比較(== 2)だと、何らかの理由でカウントが飛んだユーザーは
            // 二度とこのトリガーに当たらなくなる（issue #105 で実際に起きた）。
            // 「しきい値以上」かつ「まだ一度も使っていない」に変える。
            guard !defaults.bool(forKey: Key.launchTriggerConsumed) else { return false }
            return launchCount >= Config.launchTrigger
        case .copyMilestone:
            return copyCount > 0 && copyCount % Config.copyInterval == 0
        case .proPurchase:
            return true
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
        return days < minimumDays
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

    /// 実際のシステムレビューダイアログを呼び出す。
    @MainActor
    static func requestSystemReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        AppStore.requestReview(in: scene)
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
