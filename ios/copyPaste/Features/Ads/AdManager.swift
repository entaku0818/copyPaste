import Foundation
import GoogleMobileAds

/// AdMob広告管理
@MainActor
final class AdManager {
    static let shared = AdManager()

    /// バナー広告のAd Unit ID（Info.plist経由でxcconfigから取得）
    static var bannerAdUnitID: String {
        Bundle.main.infoDictionary?["BANNER_AD_UNIT_ID"] as? String ?? ""
    }

    /// インタースティシャル広告のAd Unit ID
    static var interstitialAdUnitID: String {
        Bundle.main.infoDictionary?["INTERSTITIAL_AD_UNIT_ID"] as? String ?? ""
    }

    /// アプリ起動（App Open）広告のAd Unit ID。
    /// 空文字の場合はApp Open広告を一切ロード・表示しない（xcconfig未設定時の保険）
    static var appOpenAdUnitID: String {
        Bundle.main.infoDictionary?["APP_OPEN_AD_UNIT_ID"] as? String ?? ""
    }

    private init() {}

    /// AdMobの初期化
    func configure() {
        MobileAds.shared.start()
    }
}
