import XCTest
import RevenueCat
@testable import ClipKit

// MARK: - 購入結果の分類（issue #113: キャンセルで「エラー」アラートが出ていた）

final class PurchaseOutcomeTests: XCTestCase {

    // MARK: - キャンセル判定

    func testIsCancellation_trueForRevenueCatCancelledError() {
        XCTAssertTrue(PurchaseOutcome.isCancellation(ErrorCode.purchaseCancelledError))
    }

    func testIsCancellation_trueForBridgedNSError() {
        // SDK は ErrorCode.errorDomain の NSError として投げてくることがある
        let error = NSError(domain: ErrorCode.errorDomain, code: ErrorCode.purchaseCancelledError.rawValue)
        XCTAssertTrue(PurchaseOutcome.isCancellation(error))
    }

    func testIsCancellation_falseForOtherErrors() {
        XCTAssertFalse(PurchaseOutcome.isCancellation(ErrorCode.networkError))
        XCTAssertFalse(PurchaseOutcome.isCancellation(ErrorCode.paymentPendingError))
        XCTAssertFalse(PurchaseOutcome.isCancellation(
            NSError(domain: "OtherDomain", code: ErrorCode.purchaseCancelledError.rawValue)
        ))
    }

    // MARK: - エラーからの分類

    func testFromError_cancelledIsNotFailure() {
        XCTAssertEqual(PurchaseOutcome.fromError(ErrorCode.purchaseCancelledError), .cancelled)
    }

    func testFromError_paymentPendingIsPending() {
        XCTAssertEqual(PurchaseOutcome.fromError(ErrorCode.paymentPendingError), .pending)
        let bridged = NSError(domain: ErrorCode.errorDomain, code: ErrorCode.paymentPendingError.rawValue)
        XCTAssertEqual(PurchaseOutcome.fromError(bridged), .pending)
    }

    func testFromError_otherErrorIsFailureWithMessage() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "通信エラー"])
        XCTAssertEqual(PurchaseOutcome.fromError(error), .failed(message: "通信エラー"))
    }

    // MARK: - 正常終了時の分類（entitlement を確認してから「購入完了」）

    func testFromResult_proActiveIsCompleted() {
        XCTAssertEqual(PurchaseOutcome.fromResult(userCancelled: false, isProActive: true), .completed)
    }

    func testFromResult_proNotActiveIsPending() {
        // 承認待ちなどで entitlement がまだ付いていない。完了とは表示しない
        XCTAssertEqual(PurchaseOutcome.fromResult(userCancelled: false, isProActive: false), .pending)
    }

    func testFromResult_userCancelledWinsOverEverything() {
        XCTAssertEqual(PurchaseOutcome.fromResult(userCancelled: true, isProActive: false), .cancelled)
        XCTAssertEqual(PurchaseOutcome.fromResult(userCancelled: true, isProActive: true), .cancelled)
    }
}
