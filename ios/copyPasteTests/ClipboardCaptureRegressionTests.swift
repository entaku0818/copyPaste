import XCTest
import UIKit
import ComposableArchitecture
@testable import ClipKit

@MainActor
final class ClipboardCaptureRegressionTests: XCTestCase {
    func testCapturesTextCopiedBeforeStateWasCreatedOnlyOnce() async {
        UIPasteboard.general.string = "Copied before launch"
        let store = TestStore(initialState: ClipboardHistoryFeature.State()) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off
        await store.send(.checkClipboard)
        await store.receive(\.addItem)
        XCTAssertEqual(store.state.items.first?.textContent, "Copied before launch")
        await store.receive(\.saveItems)
        await store.send(.checkClipboard)
        await store.finish()
        XCTAssertEqual(store.state.items.count, 1)
    }

    func testFailedReadIsRetriedAfterReturningFromSettings() async {
        UIPasteboard.general.string = "Permission now allowed"
        var state = ClipboardHistoryFeature.State()
        state.lastChangeCount = UIPasteboard.general.changeCount
        state.clipboardReadFailed = true
        let store = TestStore(initialState: state) { ClipboardHistoryFeature() }
        store.exhaustivity = .off
        await store.send(.checkClipboard)
        XCTAssertTrue(store.state.items.isEmpty, "Do not retry every timer tick")
        await store.send(.appDidEnterBackground)
        await store.send(.appDidBecomeActive)
        await store.receive(\.flushPendingPiPItems)
        await store.send(.checkClipboard)
        await store.receive(\.addItem)
        XCTAssertEqual(store.state.items.first?.textContent, "Permission now allowed")
        await store.receive(\.saveItems)
        await store.finish()
    }

    func testDifferentImagesOfSameSizeAreCaptured() async {
        let size = CGSize(width: 24, height: 24)
        let first = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let second = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        UIPasteboard.general.image = second
        var state = ClipboardHistoryFeature.State(items: [ClipboardItem(image: first, thumbnail: first)])
        state.isPiPActive = true // Skip OCR; test the capture path only.
        let store = TestStore(initialState: state) { ClipboardHistoryFeature() }
        store.exhaustivity = .off
        await store.send(.checkClipboard)
        await store.receive(\.addItem)
        await store.finish()
        XCTAssertEqual(store.state.items.count, 2)
    }
}
