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

    private init() {}

    /// AdMobの初期化
    func configure() {
        MobileAds.shared.start()
    }
}
