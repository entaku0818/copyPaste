import XCTest
@testable import ClipKit

final class ClipboardItemRowTests: XCTestCase {
    func testDisplayText_nilContent_returnsPlaceholderAndIsEmpty() {
        let result = ClipboardItemRow.displayText(for: nil)

        XCTAssertEqual(result.text, String(localized: "item.text.empty"))
        XCTAssertTrue(result.isEmpty)
    }

    func testDisplayText_emptyStringContent_returnsPlaceholderAndIsEmpty() {
        let result = ClipboardItemRow.displayText(for: "")

        XCTAssertEqual(result.text, String(localized: "item.text.empty"))
        XCTAssertTrue(result.isEmpty)
    }

    func testDisplayText_normalContent_returnsTextAndIsNotEmpty() {
        let result = ClipboardItemRow.displayText(for: "Hello, ClipKit!")

        XCTAssertEqual(result.text, "Hello, ClipKit!")
        XCTAssertFalse(result.isEmpty)
    }
}
