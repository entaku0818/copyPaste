import XCTest
@testable import ClipKit

/// `ClipboardStorageManager` の保存が非破壊であることを検証する（issue #102）。
///
/// 以前の `save(items:)` は「渡された配列こそが唯一の正しい全体像」という前提で、
/// 配列に含まれないレコードをすべて削除していた。呼び出し元の `state.items` は
/// CloudKit で他端末から届いた変更を反映していない古いスナップショットになりうるため、
/// 他端末のアイテムが削除され、その削除がCloudKit経由で相手端末にも伝播していた。
///
/// テスト実行時は `PersistenceController.shared` が in-memory ストアを使う
/// （`isRunningTests` 判定）ため、実CoreDataに対する結合テストとして書ける。
/// ストアはプロセス内で共有されるので、各テストの冒頭で `clearAll()` する。
final class ClipboardStorageManagerTests: XCTestCase {

    private var storage: ClipboardStorageManager { ClipboardStorageManager.shared }

    override func setUp() async throws {
        try await super.setUp()
        try await storage.clearAll()
    }

    // MARK: - 非破壊であること

    func testSave_doesNotDeleteRecordsMissingFromTheArray() async throws {
        let fromThisDevice = ClipboardItem(content: "this device")
        let fromOtherDevice = ClipboardItem(content: "other device")

        // 両方が保存された状態（＝CloudKit経由で他端末のアイテムも入っている状態）
        try await storage.save(items: [fromThisDevice, fromOtherDevice])

        // 他端末のアイテムを知らない古いスナップショットで保存する
        try await storage.save(items: [fromThisDevice])

        let loaded = try await storage.load()
        let ids = Set(loaded.map(\.id))
        XCTAssertTrue(
            ids.contains(fromOtherDevice.id),
            "配列に含まれていないだけのレコードを削除してはいけない（他端末のデータが消える）"
        )
        XCTAssertTrue(ids.contains(fromThisDevice.id))
        XCTAssertEqual(loaded.count, 2)
    }

    func testSave_upsertsExistingRecordWithoutDuplicating() async throws {
        var item = ClipboardItem(content: "before")
        try await storage.save(items: [item])

        item.isFavorite = true
        try await storage.save(items: [item])

        let loaded = try await storage.load()
        XCTAssertEqual(loaded.count, 1, "同じIDで二重にレコードを作らないこと")
        XCTAssertEqual(loaded.first?.isFavorite, true, "既存レコードが更新されること")
    }

    func testSave_emptyArrayDoesNotWipeTheStore() async throws {
        let item = ClipboardItem(content: "keep me")
        try await storage.save(items: [item])

        try await storage.save(items: [])

        let loaded = try await storage.load()
        XCTAssertEqual(loaded.count, 1, "空配列の保存で全消しにならないこと（全消しは clearAll の責務）")
    }

    // MARK: - ゴミ箱への移動（isInTrash の書き換えで成立すること）

    func testSaveTrash_movesExistingRecordInsteadOfDuplicating() async throws {
        var item = ClipboardItem(content: "to be trashed")
        try await storage.save(items: [item])

        // 履歴側から外し、ゴミ箱側へ入れる（reducer の removeItems と同じ流れ）
        item.deletedAt = Date()
        try await storage.saveTrash(items: [item])

        let active = try await storage.load()
        let trashed = try await storage.loadTrash()
        XCTAssertTrue(active.isEmpty, "ゴミ箱へ移したアイテムは履歴側に残らないこと")
        XCTAssertEqual(trashed.count, 1, "同じIDのレコードが履歴側とゴミ箱側に二重に作られないこと")
        XCTAssertEqual(trashed.first?.id, item.id)
    }

    func testSave_restoresRecordFromTrash() async throws {
        var item = ClipboardItem(content: "to be restored")
        item.deletedAt = Date()
        try await storage.saveTrash(items: [item])

        // 復元（reducer の restoreItem と同じ流れ）
        item.deletedAt = nil
        try await storage.save(items: [item])

        let active = try await storage.load()
        let trashed = try await storage.loadTrash()
        XCTAssertEqual(active.count, 1, "復元したアイテムが履歴側に戻ること")
        XCTAssertEqual(active.first?.id, item.id)
        XCTAssertTrue(trashed.isEmpty, "復元後はゴミ箱側に残らないこと")
    }

    // MARK: - 明示的な削除は従来どおり効くこと

    func testDeleteItem_removesOnlyTheTargetRecord() async throws {
        let keep = ClipboardItem(content: "keep")
        let remove = ClipboardItem(content: "remove")
        try await storage.save(items: [keep, remove])

        try await storage.deleteItem(remove)

        let loaded = try await storage.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, keep.id, "指定したレコードだけが削除されること")
    }

    func testClearAll_removesEverything() async throws {
        try await storage.save(items: [ClipboardItem(content: "a"), ClipboardItem(content: "b")])

        try await storage.clearAll()

        let loaded = try await storage.load()
        XCTAssertTrue(loaded.isEmpty, "clearAll は全削除であること")
    }

    func testEmptyTrash_removesTrashedRecordsOnly() async throws {
        let active = ClipboardItem(content: "active")
        var trashed = ClipboardItem(content: "trashed")
        trashed.deletedAt = Date()
        try await storage.save(items: [active])
        try await storage.saveTrash(items: [trashed])

        try await storage.emptyTrash()

        let remainingActive = try await storage.load()
        let remainingTrashed = try await storage.loadTrash()
        XCTAssertEqual(remainingActive.count, 1, "履歴側は残ること")
        XCTAssertTrue(remainingTrashed.isEmpty, "ゴミ箱側だけが空になること")
    }
}
