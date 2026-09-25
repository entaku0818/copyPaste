import Foundation

/// ペイウォールの無料トライアル訴求の表示分岐（PaywallView から利用）。
/// RevenueCat の型に依存させず、適格・非適格の分岐をユニットテストできるようにしている。
struct TrialOfferCopy: Equatable {

    /// 期間（導入オファーの期間・サブスクの更新期間の両方に使う）
    struct Period: Equatable {
        enum Unit: Equatable { case day, week, month, year }
        let unit: Unit
        let value: Int
    }

    /// 導入オファーの適格状態
    enum Eligibility: Equatable {
        case eligible
        case ineligible
        /// 判定前・判定不能・オファーなし
        case unknown
    }

    enum CallToAction: Equatable {
        /// 「無料で試す」
        case tryFree
        /// 「今すぐ始める」
        case startNow
        /// 「購入する」（買い切り）
        case purchase
    }

    /// トライアルを訴求するか（適格かつ無料トライアルの導入オファーがあるときだけ true）
    let showsTrial: Bool
    let callToAction: CallToAction
    /// プランカードに出す「7日間無料、その後 ¥300/月」
    let trialThenPriceLine: String?
    /// 注意事項（ガイドライン 3.1.2: 自動更新・キャンセル・課金タイミング）
    let notes: [String]

    /// - Parameters:
    ///   - isLifetime: 買い切りプランか
    ///   - freeTrialPeriod: 無料トライアル型の導入オファーの期間（無料トライアルでなければ nil）
    ///   - eligibility: そのユーザーの導入オファー適格状態
    ///   - localizedPrice: トライアル終了後の通常価格（StoreProduct.localizedPriceString）
    ///   - renewalPeriod: サブスクの更新期間
    static func make(
        isLifetime: Bool,
        freeTrialPeriod: Period?,
        eligibility: Eligibility,
        localizedPrice: String,
        renewalPeriod: Period?
    ) -> TrialOfferCopy {
        if isLifetime {
            return TrialOfferCopy(
                showsTrial: false,
                callToAction: .purchase,
                trialThenPriceLine: nil,
                notes: [
                    NSLocalizedString("paywall.note.lifetime", value: "• 一度の購入で永久に利用できます", comment: ""),
                    NSLocalizedString("paywall.note.billedToAppleID", value: "• Apple IDアカウントに課金されます", comment: "")
                ]
            )
        }

        let pricePerPeriod = renewalPeriod.map { priceText(localizedPrice, per: $0) } ?? localizedPrice

        guard let trial = freeTrialPeriod, eligibility == .eligible else {
            var notes: [String] = []
            if let renewalPeriod {
                notes.append(String(format: NSLocalizedString("paywall.note.autoRenew", value: "• %@ごとに自動更新", comment: ""), periodText(renewalPeriod)))
            }
            notes.append(NSLocalizedString("paywall.note.cancelAnytime", value: "• いつでもキャンセル可能", comment: ""))
            notes.append(NSLocalizedString("paywall.note.billedToAppleID", value: "• Apple IDアカウントに課金されます", comment: ""))
            return TrialOfferCopy(showsTrial: false, callToAction: .startNow, trialThenPriceLine: nil, notes: notes)
        }

        let trialLength = trialLengthText(trial)
        return TrialOfferCopy(
            showsTrial: true,
            callToAction: .tryFree,
            trialThenPriceLine: String(
                format: NSLocalizedString("paywall.trialThenPrice", value: "%1$@無料、その後 %2$@", comment: "例: 7日間無料、その後 ¥300/月"),
                trialLength, pricePerPeriod
            ),
            notes: [
                String(
                    format: NSLocalizedString("paywall.note.trialAutoRenew", value: "• %1$@の無料トライアル終了後、%2$@で自動更新されます", comment: ""),
                    trialLength, pricePerPeriod
                ),
                NSLocalizedString("paywall.note.trialCancel", value: "• トライアル終了の24時間前までにキャンセルすれば料金はかかりません", comment: ""),
                NSLocalizedString("paywall.note.cancelAnytime", value: "• いつでもキャンセル可能", comment: ""),
                NSLocalizedString("paywall.note.billedToAppleID", value: "• Apple IDアカウントに課金されます", comment: "")
            ]
        )
    }

    var callToActionTitle: String {
        switch callToAction {
        case .tryFree:  return NSLocalizedString("paywall.tryFreeCTA", value: "無料で試す", comment: "")
        case .startNow: return NSLocalizedString("paywall.startNow", value: "今すぐ始める", comment: "")
        case .purchase: return NSLocalizedString("paywall.purchase", value: "購入する", comment: "")
        }
    }

    /// 「7日間」。StoreKit は7日間を 1週間として返すことがあるため、1週間は日数で表す。
    static func trialLengthText(_ period: Period) -> String {
        switch period.unit {
        case .day:
            return String(format: NSLocalizedString("paywall.trial.days", value: "%d日間", comment: ""), period.value)
        case .week where period.value == 1:
            return String(format: NSLocalizedString("paywall.trial.days", value: "%d日間", comment: ""), 7)
        case .week:
            return String(format: NSLocalizedString("paywall.trial.weeks", value: "%d週間", comment: ""), period.value)
        case .month:
            return String(format: NSLocalizedString("paywall.trial.months", value: "%dヶ月間", comment: ""), period.value)
        case .year:
            return String(format: NSLocalizedString("paywall.trial.years", value: "%d年間", comment: ""), period.value)
        }
    }

    /// 「¥300/月」「¥2,500/年」
    static func priceText(_ price: String, per period: Period) -> String {
        let unit: String
        switch (period.unit, period.value) {
        case (.month, 1): unit = NSLocalizedString("paywall.perPeriod.month", value: "月", comment: "")
        case (.year, 1):  unit = NSLocalizedString("paywall.perPeriod.year", value: "年", comment: "")
        default:          unit = periodText(period)
        }
        return "\(price)/\(unit)"
    }

    /// 更新期間の表記（「1ヶ月」「1年」「3ヶ月」）
    static func periodText(_ period: Period) -> String {
        switch (period.unit, period.value) {
        case (.month, 1): return NSLocalizedString("paywall.period.oneMonth", value: "1ヶ月", comment: "")
        case (.year, 1):  return NSLocalizedString("paywall.period.oneYear", value: "1年", comment: "")
        default:
            switch period.unit {
            case .day:   return String(format: NSLocalizedString("paywall.period.days", value: "%d日", comment: ""), period.value)
            case .week:  return String(format: NSLocalizedString("paywall.period.weeks", value: "%d週", comment: ""), period.value)
            case .month: return String(format: NSLocalizedString("paywall.period.months", value: "%dヶ月", comment: ""), period.value)
            case .year:  return String(format: NSLocalizedString("paywall.period.years", value: "%d年", comment: ""), period.value)
            }
        }
    }
}
