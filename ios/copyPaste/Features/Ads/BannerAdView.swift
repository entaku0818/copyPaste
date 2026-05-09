import SwiftUI
import GoogleMobileAds

/// バナー広告View（無料版のみ表示）
struct BannerAdView: UIViewRepresentable {
    static var adaptiveHeight: CGFloat {
        let width = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.bounds.width ?? UIScreen.main.bounds.width
        return CGFloat(currentOrientationAnchoredAdaptiveBanner(width: width).size.height)
    }

    func makeUIView(context: Context) -> BannerView {
        let width = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.bounds.width ?? UIScreen.main.bounds.width
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = AdManager.bannerAdUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
