import Foundation
import RevenueCat

/// 購入・復元の結果をペイウォールの表示（アラート）と計測に使う形に分類したもの（issue #113）。
///
/// 以前は購入APIが投げたエラーをすべて「エラー」アラートにしていたため、
/// 購入シートでキャンセルしただけのユーザーにもエラーが出ていた。
/// また、購入APIが返った時点で entitlement を確認せず「購入完了」を出していたため、
/// 承認待ち（ファミリー共有の「承認と購入のリクエスト」等）でも完了と表示されていた。
enum PurchaseOutcome: Equatable {
    /// entitlement "pro" が有効になった
    case completed
    /// 保留中（承認待ち）。お金はまだ動いていないので完了とは言わない
    case pending
    /// ユーザーが購入シートでキャンセルした。何も表示しない
    case cancelled
    /// それ以外の失敗。メッセージをアラートに出す
    case failed(message: String)

    /// 購入APIが正常に返ったときの分類
    static func fromResult(userCancelled: Bool, isProActive: Bool) -> PurchaseOutcome {
        if userCancelled { return .cancelled }
        return isProActive ? .completed : .pending
    }

    /// 購入APIがエラーを投げたときの分類
    static func fromError(_ error: Error) -> PurchaseOutcome {
        if isCancellation(error) { return .cancelled }
        if isPending(error) { return .pending }
        return .failed(message: error.localizedDescription)
    }

    /// ユーザーのキャンセルによるエラーか。
    /// RevenueCat は `ErrorCode.purchaseCancelledError` を、SDK境界によっては
    /// `ErrorCode.errorDomain` の NSError として投げてくるので両方を見る。
    static func isCancellation(_ error: Error) -> Bool {
        matches(error, .purchaseCancelledError)
    }

    /// 支払いが保留（承認待ち）になったエラーか
    static func isPending(_ error: Error) -> Bool {
        matches(error, .paymentPendingError)
    }

    private static func matches(_ error: Error, _ code: ErrorCode) -> Bool {
        if let errorCode = error as? ErrorCode { return errorCode == code }
        let nsError = error as NSError
        return nsError.domain == ErrorCode.errorDomain && nsError.code == code.rawValue
    }
}
