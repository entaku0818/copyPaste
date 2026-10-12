import Foundation
import ComposableArchitecture

/// 自動の課金案内を出すかの判定（issue #115。シンプル録音 #228 と同じルール）。
///
/// - オンボーディング完了直後に1回だけトライアル案内（source: onboarding_trial）
/// - その後は非課金ユーザーに30日に1回（source: monthly_prompt）。起動時に判定する
/// - 使い始めて3日以内・App Open広告を出した起動・直前に全画面広告を出した直後は出さない
///
/// 判定だけを持つ純粋なロジックにして、日数・課金状態・除外条件をユニットテストで固定する。
enum AutoPaywallPolicy {
    /// 自動の課金案内（オンボーディング直後のトライアル案内を含む）の最短間隔
    static let interval: TimeInterval = 30 * 24 * 60 * 60
    /// 使い始めてから月1案内を出さない期間
    static let gracePeriod: TimeInterval = 3 * 24 * 60 * 60
    /// 全画面広告（App Open / インタースティシャル）を出してからこの間は出さない
    static let fullScreenAdCooldown: TimeInterval = 10 * 60

    enum Decision: Equatable {
        case show(PaywallSource)
        case skip(SkipReason)
    }

    /// 出さなかった理由（ログ・テスト用）
    enum SkipReason: String, Equatable {
        case pro
        case notForeground = "not_foreground"
        /// 別のモーダル（ペイウォール・満足度確認・クリップボード許可のアラート）が出ている
        case competingPrompt = "competing_prompt"
        case appOpenAdShown = "app_open_ad_shown"
        case recentFullScreenAd = "recent_full_screen_ad"
        /// 使い始めて gracePeriod 以内（起点が未記録の場合も含む）
        case gracePeriod = "grace_period"
        /// 前回の自動案内から interval 経っていない
        case throttled
    }

    static func decide(
        now: Date,
        isPro: Bool,
        isForeground: Bool,
        hasCompetingPrompt: Bool,
        didShowAppOpenAd: Bool,
        lastFullScreenAdAt: Date?,
        record: AutoPaywallRecord
    ) -> Decision {
        guard !isPro else { return .skip(.pro) }
        guard isForeground else { return .skip(.notForeground) }
        guard !hasCompetingPrompt else { return .skip(.competingPrompt) }
        guard !didShowAppOpenAd else { return .skip(.appOpenAdShown) }
        if let lastFullScreenAdAt, now.timeIntervalSince(lastFullScreenAdAt) < fullScreenAdCooldown {
            return .skip(.recentFullScreenAd)
        }
        if record.onboardingTrialPending {
            return .show(.onboardingTrial)
        }
        guard let firstSeenAt = record.firstSeenAt,
              now.timeIntervalSince(firstSeenAt) >= gracePeriod else {
            return .skip(.gracePeriod)
        }
        if let lastShownAt = record.lastShownAt, now.timeIntervalSince(lastShownAt) < interval {
            return .skip(.throttled)
        }
        return .show(.monthlyPrompt)
    }
}

/// 自動の課金案内の記録
struct AutoPaywallRecord: Equatable, Sendable {
    /// 初めて本編を開いた日時（猶予期間の起点）。このバージョンで新設したキー
    var firstSeenAt: Date?
    /// 前回、自動で課金案内を出した日時（オンボーディング直後のトライアル案内を含む）
    var lastShownAt: Date?
    /// オンボーディングを完了し、まだトライアル案内を判定していない
    var onboardingTrialPending: Bool = false
}

// MARK: - AutoPaywallClient

struct AutoPaywallClient: Sendable {
    var load: @Sendable () -> AutoPaywallRecord
    /// 起点が未記録なら今を記録する
    var recordFirstSeenIfNeeded: @Sendable () -> Void
    var markShown: @Sendable (Date) -> Void
    /// オンボーディング直後のトライアル案内は1回だけ判定する（出しても見送っても消す）
    var clearOnboardingTrial: @Sendable () -> Void
    /// フォーマットを問わず最後に全画面広告を出した時刻
    var lastFullScreenAdAt: @Sendable () async -> Date?
}

/// UserDefaults の保存先（App からオンボーディング完了を記録するためにも使う）
enum AutoPaywallStorage {
    private enum Key {
        static let firstSeenAt = "clipkit.autoPaywall.firstSeenAt"
        static let lastShownAt = "clipkit.autoPaywall.lastShownAt"
        static let onboardingTrialPending = "clipkit.autoPaywall.onboardingTrialPending"
    }

    static func load(_ defaults: UserDefaults = .standard) -> AutoPaywallRecord {
        AutoPaywallRecord(
            firstSeenAt: defaults.object(forKey: Key.firstSeenAt) as? Date,
            lastShownAt: defaults.object(forKey: Key.lastShownAt) as? Date,
            onboardingTrialPending: defaults.bool(forKey: Key.onboardingTrialPending)
        )
    }

    /// オンボーディングを完了した（初回のみ App から呼ぶ。設定からの再表示では呼ばない）
    static func markOnboardingCompleted(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Key.onboardingTrialPending)
    }

    static func recordFirstSeenIfNeeded(_ defaults: UserDefaults = .standard, now: Date = Date()) {
        guard defaults.object(forKey: Key.firstSeenAt) == nil else { return }
        defaults.set(now, forKey: Key.firstSeenAt)
    }

    static func markShown(_ date: Date, _ defaults: UserDefaults = .standard) {
        defaults.set(date, forKey: Key.lastShownAt)
    }

    static func clearOnboardingTrial(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Key.onboardingTrialPending)
    }
}

extension AutoPaywallClient: DependencyKey {
    static let liveValue = AutoPaywallClient(
        load: { AutoPaywallStorage.load() },
        recordFirstSeenIfNeeded: { AutoPaywallStorage.recordFirstSeenIfNeeded() },
        markShown: { AutoPaywallStorage.markShown($0) },
        clearOnboardingTrial: { AutoPaywallStorage.clearOnboardingTrial() },
        lastFullScreenAdAt: { await MainActor.run { FullScreenAdCoordinator.shared.lastPresentedAt } }
    )

    /// 既存テストに影響しないよう、何も記録されていない（＝自動案内が出ない）状態
    static let testValue = AutoPaywallClient(
        load: { AutoPaywallRecord() },
        recordFirstSeenIfNeeded: {},
        markShown: { _ in },
        clearOnboardingTrial: {},
        lastFullScreenAdAt: { nil }
    )
}

extension DependencyValues {
    var autoPaywall: AutoPaywallClient {
        get { self[AutoPaywallClient.self] }
        set { self[AutoPaywallClient.self] = newValue }
    }
}
