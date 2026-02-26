import Foundation
import GoogleMobileAds

/// AdMob広告管理
@MainActor
final class AdManager {
    static let shared = AdManager()

    // TODO: AdMob DashboardからAd Unit IDを取得して設定
    // テスト用IDはデバッグ時のみ使用
    #if DEBUG
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716" // テスト用
    #else
    static let bannerAdUnitID = "ca-app-pub-3484697221349891/3980413779"
    #endif

    private init() {}

    /// AdMobの初期化（AppDelegate or App.initで呼ぶ）
    func configure() {
        MobileAds.shared.start()
    }
}
