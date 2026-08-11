import XCTest
import SwiftUI
@testable import ClipKit

/// レビュー事前確認モーダルが実際に描画されることを ImageRenderer で確認する。
///
/// このビューはボトムシートから画面中央のモーダルへ変更したため、
/// 「暗幕＋中央カード」が意図どおり出るかを目視できる形で残す。
/// 出力: /tmp/clipkit_screenshots/satisfaction_modal.png
@MainActor
final class SatisfactionPromptRenderTests: XCTestCase {

    private let outputDir = URL(fileURLWithPath: "/tmp/clipkit_screenshots")

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    func testRenderSatisfactionModal() throws {
        // iPhone 17 Pro: 402×874 pt
        let width: CGFloat = 402
        let height: CGFloat = 874

        // 実際の重なりを再現するため、背面に履歴画面相当の暗い面を置いてから重ねる
        let view = ZStack {
            Color(uiColor: .systemBackground)
            SatisfactionPromptView(onSatisfied: {}, onUnsatisfied: {})
        }
        .frame(width: width, height: height)
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
        renderer.scale = 3.0

        guard let uiImage = renderer.uiImage, let pngData = uiImage.pngData() else {
            XCTFail("モーダルの描画に失敗した")
            return
        }

        // 真っ黒（＝カードが描画されていない）を検出する。
        // 中央付近にカード由来の明るいピクセルが存在することを確認する。
        XCTAssertTrue(
            Self.hasNonUniformCenter(uiImage),
            "モーダル中央にカードが描画されていない（真っ黒・空描画の疑い）"
        )

        try pngData.write(to: outputDir.appendingPathComponent("satisfaction_modal.png"))
        print("✓ satisfaction_modal.png: \(Int(uiImage.size.width * 3))×\(Int(uiImage.size.height * 3))px")
    }

    /// 画像中央付近に明暗の差があるか（一様な塗りつぶしでないか）を調べる
    private static func hasNonUniformCenter(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let width = cgImage.width
        let height = cgImage.height
        guard let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return false }
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8

        var minLuma = 255
        var maxLuma = 0
        // 中央の縦帯をサンプリングする
        for y in stride(from: height / 4, to: height * 3 / 4, by: 8) {
            for x in stride(from: width / 4, to: width * 3 / 4, by: 8) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Int(bytes[offset])
                let g = Int(bytes[offset + 1])
                let b = Int(bytes[offset + 2])
                let luma = (r * 299 + g * 587 + b * 114) / 1000
                minLuma = min(minLuma, luma)
                maxLuma = max(maxLuma, luma)
            }
        }
        // 一様なら差がほぼ0になる。カード・文字・アイコンがあれば差が出る
        return (maxLuma - minLuma) > 20
    }
}
