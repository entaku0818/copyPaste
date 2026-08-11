import XCTest
@testable import ClipKit

/// PiP中の軽量チェックポイントに上限があることを検証する（issue #94）。
///
/// 以前は上限が無く、1件appendするたびに全件をJSONで読み書きしていたため、
/// 長時間のPiPセッションで処理量がO(n²)に増大していた。
/// これは「PiP中は軽い処理だけにして背景実行の強制終了を避ける」という
/// このバッファ自体の目的を裏切っていた。
final class PendingItemBufferTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PendingItemBuffer.clear()
    }

    override func tearDown() {
        PendingItemBuffer.clear()
        super.tearDown()
    }

    func testAppend_capsBufferAtMaxBufferedItems() {
        let over = PendingItemBuffer.maxBufferedItems + 20
        for i in 0..<over {
            PendingItemBuffer.append(ClipboardItem(content: "item \(i)"))
        }

        let loaded = PendingItemBuffer.load()
        XCTAssertEqual(
            loaded.count, PendingItemBuffer.maxBufferedItems,
            "上限を超えて無制限に伸びないこと"
        )
    }

    func testAppend_keepsNewestItemsWhenOverCapacity() {
        let over = PendingItemBuffer.maxBufferedItems + 5
        var appended: [ClipboardItem] = []
        for i in 0..<over {
            let item = ClipboardItem(content: "item \(i)")
            appended.append(item)
            PendingItemBuffer.append(item)
        }

        let loaded = PendingItemBuffer.load()
        XCTAssertEqual(
            loaded.last?.id, appended.last?.id,
            "最後にappendしたアイテムは残ること（新しい方を優先して保持する）"
        )
        XCTAssertFalse(
            loaded.contains(where: { $0.id == appended.first?.id }),
            "あふれた古いアイテムは頭から捨てられること"
        )
    }

    func testClear_emptiesBuffer() {
        PendingItemBuffer.append(ClipboardItem(content: "x"))
        XCTAssertFalse(PendingItemBuffer.load().isEmpty)

        PendingItemBuffer.clear()

        XCTAssertTrue(PendingItemBuffer.load().isEmpty, "clearでバッファが空になること")
    }

    func testLoad_returnsAppendedItemsInOrder() {
        let a = ClipboardItem(content: "a")
        let b = ClipboardItem(content: "b")
        PendingItemBuffer.append(a)
        PendingItemBuffer.append(b)

        let loaded = PendingItemBuffer.load()
        XCTAssertEqual(loaded.map(\.id), [a.id, b.id], "append順が保たれること")
    }
}
