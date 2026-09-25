import XCTest
@testable import ClipKit

// MARK: - ペイウォールの無料トライアル表示分岐のテスト
//
// 適格ユーザーにだけ「7日間無料、その後 ¥300/月」と「無料で試す」を出し、
// 非適格・判定不能は従来表示にすることを検証する。
// 文言はテスト実行環境の言語で変わるため、価格・日数・分岐フラグで検証する。

final class TrialOfferCopyTests: XCTestCase {

    private let oneWeek = TrialOfferCopy.Period(unit: .week, value: 1)
    private let sevenDays = TrialOfferCopy.Period(unit: .day, value: 7)
    private let oneMonth = TrialOfferCopy.Period(unit: .month, value: 1)
    private let oneYear = TrialOfferCopy.Period(unit: .year, value: 1)

    // MARK: - 適格

    func testEligible_showsTrialLineWithPriceAndTryFreeCTA() {
        let copy = TrialOfferCopy.make(
            isLifetime: false, freeTrialPeriod: sevenDays, eligibility: .eligible,
            localizedPrice: "¥300", renewalPeriod: oneMonth
        )
        XCTAssertTrue(copy.showsTrial)
        XCTAssertEqual(copy.callToAction, .tryFree)
        let line = copy.trialThenPriceLine
        XCTAssertNotNil(line)
        XCTAssertTrue(line?.contains("7") == true, "トライアル日数が入ること: \(line ?? "nil")")
        XCTAssertTrue(line?.contains("¥300/") == true, "トライアル後の価格が入ること: \(line ?? "nil")")
    }

    func testEligible_oneWeekTrialIsShownAsSevenDays() {
        let fromWeek = TrialOfferCopy.make(
            isLifetime: false, freeTrialPeriod: oneWeek, eligibility: .eligible,
            localizedPrice: "¥2,500", renewalPeriod: oneYear
        )
        let fromDays = TrialOfferCopy.make(
            isLifetime: false, freeTrialPeriod: sevenDays, eligibility: .eligible,
            localizedPrice: "¥2,500", renewalPeriod: oneYear
        )
        XCTAssertEqual(fromWeek.trialThenPriceLine, fromDays.trialThenPriceLine, "1週間は7日間として表示すること")
    }

    func testEligible_notesStateAutoRenewAfterTrialAndCancellation() {
        let copy = TrialOfferCopy.make(
            isLifetime: false, freeTrialPeriod: sevenDays, eligibility: .eligible,
            localizedPrice: "¥300", renewalPeriod: oneMonth
        )
        XCTAssertTrue(copy.notes.contains { $0.contains("¥300/") }, "トライアル終了後の自動課金額を明記すること")
        XCTAssertTrue(copy.notes.contains(
            NSLocalizedString("paywall.note.cancelAnytime", value: "• いつでもキャンセル可能", comment: "")
        ), "いつでもキャンセル可を明記すること")
        XCTAssertTrue(copy.notes.contains(
            NSLocalizedString("paywall.note.trialCancel", value: "", comment: "")
        ))
    }

    // MARK: - 非適格・判定不能

    func testIneligible_showsRegularCopy() {
        let copy = TrialOfferCopy.make(
            isLifetime: false, freeTrialPeriod: sevenDays, eligibility: .ineligible,
            localizedPrice: "¥300", renewalPeriod: oneMonth
        )
        XCTAssertFalse(copy.showsTrial)
        XCTAssertEqual(copy.callToAction, .startNow)
        XCTAssertNil(copy.trialThenPriceLine)
        XCTAssertFalse(copy.notes.contains(
            NSLocalizedString("paywall.note.trialCancel", value: "", comment: "")
        ), "非適格にトライアルの注意書きを出さないこと")
        XCTAssertTrue(copy.notes.contains(
            NSLocalizedString("paywall.note.cancelAnytime", value: "• いつでもキャンセル可能", comment: "")
        ))
    }

    func testUnknownEligibility_isTreatedAsIneligible() {
        let copy = TrialOfferCopy.make(
            isLifetime: false, freeTrialPeriod: sevenDays, eligibility: .unknown,
            localizedPrice: "¥300", renewalPeriod: oneMonth
        )
        XCTAssertFalse(copy.showsTrial)
        XCTAssertEqual(copy.callToAction, .startNow)
    }

    func testEligibleButNoFreeTrialOffer_showsRegularCopy() {
        let copy = TrialOfferCopy.make(
            isLifetime: false, freeTrialPeriod: nil, eligibility: .eligible,
            localizedPrice: "¥300", renewalPeriod: oneMonth
        )
        XCTAssertFalse(copy.showsTrial)
        XCTAssertNil(copy.trialThenPriceLine)
    }

    // MARK: - 買い切り

    func testLifetime_neverShowsTrial() {
        let copy = TrialOfferCopy.make(
            isLifetime: true, freeTrialPeriod: nil, eligibility: .eligible,
            localizedPrice: "¥4,000", renewalPeriod: nil
        )
        XCTAssertFalse(copy.showsTrial)
        XCTAssertEqual(copy.callToAction, .purchase)
    }

    // MARK: - ローカライズ漏れ

    func testTrialStringsExistInJapaneseAndEnglish() throws {
        let keys = [
            "paywall.trialThenPrice", "paywall.note.trialAutoRenew", "paywall.note.trialCancel",
            "paywall.tryFreeCTA", "paywall.perPeriod.month", "paywall.perPeriod.year",
            "paywall.trial.days", "paywall.startNow", "paywall.purchase",
            "paywall.note.autoRenew", "paywall.note.cancelAnytime", "paywall.note.billedToAppleID"
        ]
        let appBundle = Bundle(for: RevenueCatManager.self)
        for lang in ["ja", "en"] {
            let path = try XCTUnwrap(appBundle.path(forResource: lang, ofType: "lproj"), "\(lang).lproj がない")
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys {
                let value = bundle.localizedString(forKey: key, value: "__missing__", table: nil)
                XCTAssertNotEqual(value, "__missing__", "\(lang) に \(key) がない")
            }
        }
    }
}
