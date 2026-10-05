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
