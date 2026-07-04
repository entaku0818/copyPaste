import XCTest
import UIKit
@testable import ClipKit

final class TextTransformerTests: XCTestCase {

    // MARK: - Case conversion

    func testUppercase() {
        XCTAssertEqual(TextTransform.uppercase.apply(to: "Hello World"), "HELLO WORLD")
    }

    func testLowercase() {
        XCTAssertEqual(TextTransform.lowercase.apply(to: "Hello World"), "hello world")
    }

    // MARK: - Line breaks / whitespace

    func testRemoveLineBreaks() {
        XCTAssertEqual(TextTransform.removeLineBreaks.apply(to: "a\nb\r\nc"), "abc")
    }

    func testRemoveLineBreaks_noNewlines() {
        XCTAssertEqual(TextTransform.removeLineBreaks.apply(to: "abc"), "abc")
    }

    func testTrimWhitespace() {
        XCTAssertEqual(TextTransform.trimWhitespace.apply(to: "  hello \n"), "hello")
    }

    func testTrimWhitespace_keepsInnerWhitespace() {
        XCTAssertEqual(TextTransform.trimWhitespace.apply(to: " hello world "), "hello world")
    }

    // MARK: - snake_case / camelCase

    func testSnakeCase_fromCamelCase() {
        XCTAssertEqual(TextTransform.snakeCase.apply(to: "helloWorldExample"), "hello_world_example")
    }

    func testSnakeCase_fromSpacesAndHyphens() {
        XCTAssertEqual(TextTransform.snakeCase.apply(to: "hello world-example"), "hello_world_example")
    }

    func testSnakeCase_fromConsecutiveUppercase() {
        XCTAssertEqual(TextTransform.snakeCase.apply(to: "HTTPServer"), "http_server")
    }

    func testCamelCase_fromSnakeCase() {
        XCTAssertEqual(TextTransform.camelCase.apply(to: "hello_world_example"), "helloWorldExample")
    }

    func testCamelCase_fromSpaces() {
        XCTAssertEqual(TextTransform.camelCase.apply(to: "hello world"), "helloWorld")
    }

    func testCamelCase_preservesInnerCaps() {
        XCTAssertEqual(TextTransform.camelCase.apply(to: "SomeVariable_name"), "someVariableName")
    }

    // MARK: - Full-width / half-width

    func testFullWidth() {
        XCTAssertEqual(TextTransform.fullWidth.apply(to: "ABC123"), "ＡＢＣ１２３")
    }

    func testHalfWidth() {
        XCTAssertEqual(TextTransform.halfWidth.apply(to: "ＡＢＣ１２３"), "ABC123")
    }

    // MARK: - Markdown removal

    func testRemoveMarkdown_heading() {
        XCTAssertEqual(TextTransform.removeMarkdown.apply(to: "# Title"), "Title")
    }

    func testRemoveMarkdown_boldAndLink() {
        XCTAssertEqual(
            TextTransform.removeMarkdown.apply(to: "**bold** and [link](https://example.com)"),
            "bold and link"
        )
    }

    func testRemoveMarkdown_listAndInlineCode() {
        XCTAssertEqual(
            TextTransform.removeMarkdown.apply(to: "- item with `code`"),
            "item with code"
        )
    }

    func testRemoveMarkdown_codeFence() {
        let input = """
        ```swift
        let x = 1
        ```
        """
        XCTAssertEqual(TextTransform.removeMarkdown.apply(to: input), "let x = 1\n")
    }

    func testRemoveMarkdown_plainTextUnchanged() {
        XCTAssertEqual(TextTransform.removeMarkdown.apply(to: "plain text"), "plain text")
    }

    // MARK: - URL encode / decode

    func testURLEncode() {
        XCTAssertEqual(TextTransform.urlEncode.apply(to: "hello world"), "hello%20world")
        XCTAssertEqual(TextTransform.urlEncode.apply(to: "a&b=c"), "a%26b%3Dc")
    }

    func testURLDecode() {
        XCTAssertEqual(TextTransform.urlDecode.apply(to: "hello%20world"), "hello world")
    }

    func testURLEncodeDecode_roundTrip() {
        let original = "日本語 テキスト&query=値"
        let encoded = TextTransform.urlEncode.apply(to: original)
        XCTAssertEqual(TextTransform.urlDecode.apply(to: encoded), original)
    }

    // MARK: - Free / Pro split

    func testFreeTransforms() {
        let free: Set<TextTransform> = [.uppercase, .lowercase, .removeLineBreaks, .trimWhitespace]
        for transform in TextTransform.allCases {
            XCTAssertEqual(
                transform.requiresPro,
                !free.contains(transform),
                "\(transform) requiresPro should be \(!free.contains(transform))"
            )
        }
    }

    // MARK: - Display properties

    func testDisplayNames_areNonEmpty() {
        for transform in TextTransform.allCases {
            XCTAssertFalse(transform.displayName.isEmpty, "\(transform) displayName should not be empty")
        }
    }

    func testSystemImageNames_areValidSymbols() {
        for transform in TextTransform.allCases {
            XCTAssertNotNil(
                UIImage(systemName: transform.systemImageName),
                "\(transform) systemImageName '\(transform.systemImageName)' should be a valid SF Symbol"
            )
        }
    }
}
