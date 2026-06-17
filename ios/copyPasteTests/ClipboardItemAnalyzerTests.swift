import XCTest
@testable import ClipKit

final class ClipboardItemAnalyzerTests: XCTestCase {

    // MARK: - URL detection

    func testCategory_detectsURL() {
        XCTAssertEqual(ClipboardItemAnalyzer.category(for: "https://example.com"), .url)
        XCTAssertEqual(ClipboardItemAnalyzer.category(for: "http://apple.com/jp"), .url)
    }

    func testCategory_detectsEmail() {
        XCTAssertEqual(ClipboardItemAnalyzer.category(for: "user@example.com"), .email)
        XCTAssertEqual(ClipboardItemAnalyzer.category(for: "mailto:foo@bar.com"), .email)
    }

    func testCategory_detectsPhoneNumber() {
        XCTAssertEqual(ClipboardItemAnalyzer.category(for: "090-1234-5678"), .phone)
        XCTAssertEqual(ClipboardItemAnalyzer.category(for: "+81-3-1234-5678"), .phone)
    }

    // MARK: - Code detection

    func testCategory_detectsSwiftCode() {
        let code = """
        func hello() {
            let x = 42
            return x
        }
        """
        XCTAssertEqual(ClipboardItemAnalyzer.category(for: code), .code)
    }

    func testCategory_detectsJavaScriptCode() {
        let code = "const foo = () => { return 42; };"
        XCTAssertEqual(ClipboardItemAnalyzer.category(for: code), .code)
    }

    func testCategory_plainTextFallsBackToText() {
        XCTAssertEqual(ClipboardItemAnalyzer.category(for: "こんにちは世界"), .text)
        XCTAssertEqual(ClipboardItemAnalyzer.category(for: "Hello world, how are you?"), .text)
    }

    // MARK: - ItemCategory properties

    func testItemCategory_displayNames_areNonEmpty() {
        for cat in ItemCategory.allCases {
            XCTAssertFalse(cat.displayName.isEmpty, "\(cat) displayName should not be empty")
        }
    }

    func testItemCategory_systemImageNames_areNonEmpty() {
        for cat in ItemCategory.allCases {
            XCTAssertFalse(cat.systemImageName.isEmpty, "\(cat) systemImageName should not be empty")
        }
    }

    func testItemCategory_rawValueRoundTrip() {
        for cat in ItemCategory.allCases {
            XCTAssertEqual(ItemCategory(rawValue: cat.rawValue), cat)
        }
    }

    // MARK: - OCR (synchronous smoke test — no actual image, just nil path)

    func testExtractText_returnsNilForOpaqueImage() async {
        let image = UIImage()
        let result = await ClipboardItemAnalyzer.extractText(from: image)
        XCTAssertNil(result)
    }
}
