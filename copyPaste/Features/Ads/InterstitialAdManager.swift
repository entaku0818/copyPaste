import Foundation
import GoogleMobileAds
import UIKit

/// インタースティシャル広告管理（起動時・一定回数ペースト後に表示）
@MainActor
final class InterstitialAdManager: NSObject, ObservableObject {
    static let shared = InterstitialAdManager()

    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910" // テスト用
    #else
    private let adUnitID = "YOUR_INTERSTITIAL_AD_UNIT_ID" // 本番用
    #endif

    private var interstitial: InterstitialAd?
    private var pasteCount = 0
    private let showInterval = 5 // 5回ペーストごとに表示

    private override init() {
        super.init()
    }

    /// 広告をプリロード
    func loadAd() async {
        do {
            interstitial = try await InterstitialAd.load(
                with: adUnitID,
                request: Request()
            )
        } catch {
            print("InterstitialAd failed to load: \(error)")
        }
    }

    /// アイテムをペーストした時に呼ぶ
    func onItemPasted(isProUser: Bool) {
        // Pro版は広告なし
        guard !isProUser else { return }

        pasteCount += 1
        if pasteCount >= showInterval {
            pasteCount = 0
            showAd()
        }
    }

    /// 広告を表示
    private func showAd() {
        guard let interstitial,
              let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?
                .rootViewController else { return }

        interstitial.present(from: rootVC)

        // 次の広告をプリロード
        Task {
            await loadAd()
        }
    }
}
