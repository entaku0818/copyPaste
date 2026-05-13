import XCTest
import SwiftUI
@testable import ClipKit

// Renders App Store screenshots (iPhone 16 Pro Max: 1320×2868 px) for all screens and languages.
// Output: /tmp/clipkit_screenshots/{lang}_{index}_{screen}.png
// Run: xcodebuild test -scheme ClipKit -project ios/copyPaste.xcodeproj
//        -destination 'platform=iOS Simulator,id=C3D7C731-0C93-4FE5-85E1-223D72A26A11'
//        -only-testing:copyPasteTests/ScreenshotRenderTests

@MainActor
final class ScreenshotRenderTests: XCTestCase {

    private let outputDir = URL(fileURLWithPath: "/tmp/clipkit_screenshots")

    // iPhone 16 Pro Max: 1320×2868 px → 440×956 pt @3x
    private let logicalWidth: CGFloat  = 440
    private let logicalHeight: CGFloat = 956
    private let scale: CGFloat = 3.0

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    private let targetScreens: [ScreenshotScreen] = [
        .clipboardHistory,
        .keyboardPreview,
        .widget,
        .favorites,
        .keyboardSetup,
    ]

    func testRenderAllScreenshots() throws {
        for lang in AppLanguage.allCases {
            for screen in targetScreens {
                let view = self.makeScreenshotView(screen: screen, language: lang)
                    .frame(width: logicalWidth, height: logicalHeight)
                let filename = "\(lang.rawValue)_\(screen.rawValue).png"
                try self.renderAndSave(view: view, filename: filename)
            }
        }
    }

    // iPad Pro 12.9" (3rd gen): 2048×2732 px → 1024×1366 pt @2x
    private let iPadLogicalWidth: CGFloat  = 1024
    private let iPadLogicalHeight: CGFloat = 1366
    private let iPadScale: CGFloat = 2.0

    func testRenderIPadScreenshots() throws {
        for lang in AppLanguage.allCases {
            for screen in targetScreens {
                let view = self.makeScreenshotView(screen: screen, language: lang)
                    .frame(width: iPadLogicalWidth, height: iPadLogicalHeight)
                let filename = "\(lang.rawValue)_ipad_\(screen.rawValue).png"
                try self.renderAndSaveIPad(view: view, filename: filename)
            }
        }
    }

    // MARK: - Private

    private func makeScreenshotView(screen: ScreenshotScreen, language: AppLanguage) -> some View {
        let cap = screen.caption(language: language)
        let bg  = screen.screenshotBackground
        return AppStoreScreenshotView(caption: cap, background: bg) {
            screenshotContent(for: screen, language: language)
        }
    }

    private func renderAndSave<V: View>(view: V, filename: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: logicalWidth, height: logicalHeight)
        renderer.scale = scale
        guard let uiImage = renderer.uiImage, let pngData = uiImage.pngData() else {
            XCTFail("Render failed: \(filename)"); return
        }
        try pngData.write(to: outputDir.appendingPathComponent(filename))
        print("✓ \(filename): \(Int(uiImage.size.width * scale))×\(Int(uiImage.size.height * scale))px")
    }

    private func renderAndSaveIPad<V: View>(view: V, filename: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: iPadLogicalWidth, height: iPadLogicalHeight)
        renderer.scale = iPadScale
        guard let uiImage = renderer.uiImage, let pngData = uiImage.pngData() else {
            XCTFail("Render failed: \(filename)"); return
        }
        try pngData.write(to: outputDir.appendingPathComponent(filename))
        print("✓ \(filename): \(Int(uiImage.size.width * iPadScale))×\(Int(uiImage.size.height * iPadScale))px")
    }
}
