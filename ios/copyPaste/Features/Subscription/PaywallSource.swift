import Foundation
import ComposableArchitecture
import FirebaseAnalytics

/// 課金画面をどこから開いたか（issue #109）。
/// `show_paywall` の `source` パラメータとしてそのままGA4に送るので、rawValueは変えないこと
/// （変えると入口別CVRの時系列が途切れる）。
enum PaywallSource: String, CaseIterable, Equatable, Sendable {
    /// 履歴タブのPro誘導バナー
    case historyBanner = "history_banner"
    /// お気に入り上限（無料10件）超過
    case favoriteLimit = "favorite_limit"
    /// スニペット上限（無料3件）超過（reducer側のガード）
    case snippetLimit = "snippet_limit"
    /// キーボード拡張のアップグレードカード（clipkit://subscription）
    case keyboard = "keyboard"
    /// 項目詳細のPro限定テキスト変換（履歴・お気に入りの両方から開く）
    case textTransform = "text_transform"
    /// スニペットタブの「＋」（上限時）
    case snippetsAddButton = "snippets_add_button"
    /// 設定タブのProヒーローカード
    case settingsHero = "settings_hero"
    /// お気に入りタブのPro誘導バナー
    case favoritesBanner = "favorites_banner"
    /// ウィジェットの無料表示（clipkit://subscription?source=widget, issue #116）
    case widget = "widget"
    /// 設定のゴミ箱（無料はロック表示, issue #116）
    case settingsTrash = "settings_trash"
    /// 設定のエクスポート（無料はロック表示, issue #116）
    case settingsExport = "settings_export"
    /// 設定のiCloud同期（無料はロック表示, issue #116）
    case settingsICloud = "settings_icloud"

    /// アプリを開いたURL（clipkit://subscription）から入口を決める。
    /// キーボード拡張は source を付けずに開く旧形式もあるので、無い・不明なら keyboard とみなす。
    /// ペイウォールを開くURLでなければ nil
    static func fromDeepLink(_ url: URL) -> PaywallSource? {
        guard url.scheme == "clipkit", url.host == "subscription" else { return nil }
        let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "source" })?.value
        return value.flatMap(PaywallSource.init(rawValue:)) ?? .keyboard
    }
}

// MARK: - PaywallAnalyticsClient

// show_paywall の送信をDependency化する（issue #109）。
// 以前はreducerの1箇所でしか送っておらず、View側の@Stateシートから開く入口が計測漏れしていた。
// 全入口をreducer経由でここに集め、各入口がsource付きで送ることをテストで固定する。
struct PaywallAnalyticsClient {
    var logShown: @Sendable (PaywallSource) -> Void
}

extension PaywallAnalyticsClient: DependencyKey {
    static let liveValue = PaywallAnalyticsClient(
        logShown: { source in
            Analytics.logEvent("show_paywall", parameters: ["source": source.rawValue])
        }
    )

    static let testValue = PaywallAnalyticsClient(
        logShown: { _ in }
    )
}

extension DependencyValues {
    var paywallAnalytics: PaywallAnalyticsClient {
        get { self[PaywallAnalyticsClient.self] }
        set { self[PaywallAnalyticsClient.self] = newValue }
    }
}

// MARK: - 購入・復元・閉じるの計測（issue #114）

/// ペイウォール上で起きたこと。GA4のイベント名になるので rawValue は変えないこと。
/// 以前は show_paywall しか無く、入口別の購入率もキャンセル数も測れなかった。
enum PaywallEvent: String, CaseIterable, Equatable, Sendable {
    case purchaseStarted = "paywall_purchase_started"
    case purchaseCompleted = "paywall_purchase_completed"
    /// 承認待ち（保留）。完了とは分けて数える
    case purchasePending = "paywall_purchase_pending"
    case purchaseCancelled = "paywall_purchase_cancelled"
    case purchaseFailed = "paywall_purchase_failed"
    case restoreStarted = "paywall_restore_started"
    case restoreCompleted = "paywall_restore_completed"
    /// 復元できる購入が無かった・エラーになった
    case restoreFailed = "paywall_restore_failed"
    /// ペイウォールが閉じられた（購入の有無は purchased パラメータ）
    case dismissed = "paywall_dismissed"

    /// 購入結果に対応するイベント
    static func forPurchase(_ outcome: PurchaseOutcome) -> PaywallEvent {
        switch outcome {
        case .completed: return .purchaseCompleted
        case .pending: return .purchasePending
        case .cancelled: return .purchaseCancelled
        case .failed: return .purchaseFailed
        }
    }
}

/// どのプランを選んでいたか。`plan` パラメータの値
enum PaywallPlan: String, Equatable, Sendable {
    case monthly
    case annual
    case lifetime
    case other
}

/// イベントに載せるパラメータ。RevenueCat の型に依存させずテストで固定する
struct PaywallEventParameters: Equatable {
    let source: PaywallSource
    /// 選択中のプラン（プラン未読込なら nil）
    var plan: PaywallPlan?
    /// 選択中のプランが無料トライアルの対象として表示されていたか
    var trialEligible: Bool?
    /// paywall_dismissed のみ: このペイウォールで購入（または復元）が完了したか
    var purchased: Bool?

    var dictionary: [String: String] {
        var params = ["source": source.rawValue]
        if let plan { params["plan"] = plan.rawValue }
        if let trialEligible { params["trial_eligible"] = trialEligible ? "true" : "false" }
        if let purchased { params["purchased"] = purchased ? "true" : "false" }
        return params
    }
}

extension PaywallAnalyticsClient {
    /// ペイウォール内のイベントを送る（View から直接呼ぶ）
    static func log(_ event: PaywallEvent, _ parameters: PaywallEventParameters) {
        Analytics.logEvent(event.rawValue, parameters: parameters.dictionary)
    }
}
