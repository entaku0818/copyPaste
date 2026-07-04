import Foundation
import GoogleMobileAds
import UIKit

/// インタースティシャル広告管理（起動時・一定回数ペースト後に表示）
@MainActor
final class InterstitialAdManager: NSObject, ObservableObject {
    static let shared = InterstitialAdManager()

    private var adUnitID: String {
        AdManager.interstitialAdUnitID
    }

    private var interstitial: InterstitialAd?
    private var pasteCount = 0
    private let showInterval = 5 // 5回ペーストごとに表示

    private override init() {
        super.init()
    }

    /// 広告をプリロード（ロード済みならスキップ）
    func loadAd() async {
        guard interstitial == nil else { return }
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

        // インタースティシャルは1回しか表示できないため破棄し、次の広告をプリロード
        self.interstitial = nil
        Task {
            await loadAd()
        }
    }
}
