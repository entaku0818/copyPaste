import XCTest
@testable import ClipKit

/// 履歴エクスポート（Pro機能）のフォーマットと後片付けを検証する。
/// issue #72（書き込みエラーの握り潰し）/ #78・#73（テスト不在）/ #80（一時ファイル残置）。
final class ExportManagerTests: XCTestCase {

    private func item(
        _ text: String,
        at timestamp: Date,
        favorite: Bool = false,
        category: ItemCategory? = nil
    ) -> ClipboardItem {
        var item = ClipboardItem(id: UUID(), content: text, timestamp: timestamp, isFavorite: favorite)
        item.category = category
        return item
    }

    // MARK: - CSV

    func testCSV_escapesDoubleQuotes() throws {
        let url = try XCTUnwrap(
            ExportManager.export(
                [item("say \"hello\"", at: Date(timeIntervalSince1970: 0))],
                format: .csv
            )
        )
        defer { ExportManager.cleanUp(url) }
        let csv = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(
            csv.contains("\"say \"\"hello\"\"\""),
            "CSVのクォートは \"\" にエスケープされること。実際: \(csv)"
        )
    }

    func testCSV_emptyItemsProducesHeaderOnly() throws {
        let url = try XCTUnwrap(ExportManager.export([], format: .csv))
        defer { ExportManager.cleanUp(url) }
        let csv = try String(contentsOf: url, encoding: .utf8)

        XCTAssertEqual(
            csv, "timestamp,type,category,favorite,content",
            "0件ならヘッダー行だけになること"
        )
    }

    func testCSV_nilCategoryBecomesEmptyColumn() throws {
        let url = try XCTUnwrap(
            ExportManager.export([item("no category", at: Date(timeIntervalSince1970: 0))], format: .csv)
        )
        defer { ExportManager.cleanUp(url) }
        let csv = try String(contentsOf: url, encoding: .utf8)
        let dataLine = try XCTUnwrap(csv.components(separatedBy: "\n").last)

        XCTAssertTrue(dataLine.contains(",text,,0,"), "categoryがnilなら空欄になること。実際: \(dataLine)")
    }

    // MARK: - Markdown

    func testMarkdown_groupsItemsOfSameDayUnderOneHeading() throws {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let url = try XCTUnwrap(
            ExportManager.export(
                [item("first", at: day), item("second", at: day.addingTimeInterval(60))],
                format: .markdown
            )
        )
        defer { ExportManager.cleanUp(url) }
        let md = try String(contentsOf: url, encoding: .utf8)

        let headingCount = md.components(separatedBy: "\n").filter { $0.hasPrefix("## ") }.count
        XCTAssertEqual(headingCount, 1, "同じ日のアイテムは1つの見出しにまとまること")
    }

    func testMarkdown_truncatesPreviewOver80Characters() throws {
        let long = String(repeating: "あ", count: 100)
        let url = try XCTUnwrap(
            ExportManager.export([item(long, at: Date(timeIntervalSince1970: 0))], format: .markdown)
        )
        defer { ExportManager.cleanUp(url) }
        let md = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(md.contains("…"), "80文字を超えるプレビューは省略記号がつくこと")
        XCTAssertFalse(md.contains(long), "全文がそのまま出ないこと")
    }

    func testMarkdown_usesOnlyFirstLineOfMultilineContent() throws {
        let url = try XCTUnwrap(
            ExportManager.export(
                [item("first line\nsecond line", at: Date(timeIntervalSince1970: 0))],
                format: .markdown
            )
        )
        defer { ExportManager.cleanUp(url) }
        let md = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(md.contains("first line"))
        XCTAssertFalse(md.contains("second line"), "プレビューは先頭行だけを使うこと")
    }

    func testMarkdown_marksFavoriteItems() throws {
        let url = try XCTUnwrap(
            ExportManager.export(
                [item("starred", at: Date(timeIntervalSince1970: 0), favorite: true)],
                format: .markdown
            )
        )
        defer { ExportManager.cleanUp(url) }
        let md = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(md.contains("⭐"), "お気に入りには印がつくこと")
    }

    // MARK: - 後片付け（issue #80）

    func testCleanUp_removesExportedFile() throws {
        let url = try XCTUnwrap(
            ExportManager.export([item("bye", at: Date(timeIntervalSince1970: 0))], format: .csv)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "書き出し直後は存在すること")

        ExportManager.cleanUp(url)

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: url.path),
            "共有後に一時ファイルが残置されないこと（履歴には機微な情報が含まれうる）"
        )
    }
}
