import XCTest
import SwiftUI
@testable import ClipKit

// 無料トライアルのペイウォール表示を目視確認するためのスナップショット。
// 実物の PaywallView を RevenueCat + App Store サンドボックスの商品情報で表示して保存する
// （サンドボックスでは購入履歴がないので適格＝トライアル表示になる）。
// SKTestSession はアプリ起動時に RevenueCat が商品をキャッシュ済みのため効かない。
// ネットワークが要るため通常の test では skip し、明示したときだけ走らせる:
//   TEST_RUNNER_TRIAL_PAYWALL_SNAPSHOT=1 xcodebuild test ... -testLanguage ja \
//     -only-testing:ClipKitTests/TrialPaywallSnapshotTests
// Output: /tmp/clipkit_trial_paywall/{lang}_eligible.png（と商品・適格判定の診断 .txt）

@MainActor
final class TrialPaywallSnapshotTests: XCTestCase {

    private let outputDir = URL(fileURLWithPath: "/tmp/clipkit_trial_paywall")

    func testSnapshotTrialPaywall() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["TRIAL_PAYWALL_SNAPSHOT"] == "1",
            "目視確認用。TEST_RUNNER_TRIAL_PAYWALL_SNAPSHOT=1 のときだけ実行する"
        )
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let lang = Bundle.main.preferredLocalizations.first ?? "unknown"
        try await snapshotPaywall(named: "\(lang)_eligible")
    }

    private func snapshotPaywall(named name: String) async throws {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        // プラン選択と注意事項まで1枚に収めるため縦に伸ばす
        window.frame = CGRect(x: 0, y: 0, width: scene.screen.bounds.width, height: 1_900)
        window.rootViewController = UIHostingController(rootView: PaywallView())
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        // Offering 取得・適格判定の完了を待つ
        try await Task.sleep(for: .seconds(8))

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let url = outputDir.appendingPathComponent("\(name).png")
        try XCTUnwrap(image.pngData()).write(to: url)
        let packages = RevenueCatManager.shared.offerings?.current?.availablePackages ?? []
        let diag = packages.map { pkg -> String in
            let product = pkg.storeProduct
            let intro = product.introductoryDiscount.map { "\($0.paymentMode.rawValue):\($0.subscriptionPeriod.value)x\($0.subscriptionPeriod.unit.rawValue)" } ?? "none"
            let status = RevenueCatManager.shared.introEligibility[product.productIdentifier].map { "\($0.rawValue)" } ?? "nil"
            return "\(product.productIdentifier) price=\(product.localizedPriceString) intro=\(intro) eligibility=\(status)"
        }.joined(separator: "\n")
        try diag.write(to: outputDir.appendingPathComponent("\(name).txt"), atomically: true, encoding: .utf8)
    }
}
