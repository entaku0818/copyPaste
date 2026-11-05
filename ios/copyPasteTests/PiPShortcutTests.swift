import XCTest
@testable import ClipKit

@MainActor
final class PiPShortcutTests: XCTestCase {
    func testLaunchRequestSurvivesUntilScreenConsumesIt() {
        let request = PiPLaunchRequest()
        XCTAssertFalse(request.isPending)
        request.request()
        XCTAssertTrue(request.isPending)
        request.request()
        XCTAssertTrue(request.isPending)
        request.consume()
        XCTAssertFalse(request.isPending)
        request.request()
        XCTAssertTrue(request.isPending)
    }

    func testIntentQueuesLaunchRequest() async throws {
        defer { PiPLaunchRequest.shared.consume() }
        PiPLaunchRequest.shared.consume()
        _ = try await OpenPiPIntent().perform()
        XCTAssertTrue(PiPLaunchRequest.shared.isPending)
    }

    func testCompactModeBeforeAndAfterViewLoads() {
        let controller = ClipboardPiPViewController()
        controller.setCompactMode(true)
        controller.loadViewIfNeeded()
        XCTAssertTrue(controller.isCompact)
        XCTAssertEqual(controller.preferredContentSize, CGSize(width: 240, height: 100))
        controller.setCompactMode(false)
        XCTAssertFalse(controller.isCompact)
        XCTAssertEqual(controller.preferredContentSize, CGSize(width: 240, height: 135))
    }
}
