import XCTest
@testable import ClipKit

/// JSONMigration（旧 JSON ストレージ → CoreData へのデータ移行）のテスト。
///
/// 移行失敗は既存ユーザーのデータロスに直結するため、
/// - 平文/暗号化された旧データが欠落なく移行されること（roundtrip）
/// - 破損データでクラッシュせず安全に処理されること
/// - 既に移行済みなら再実行されないこと（旧データを上書き・消失させない）
/// を担保する。
///
/// App Group コンテナにアクセスできない実行環境では XCTSkip する。
final class JSONMigrationTests: XCTestCase {

    private let migrationKey = "coreDataMigrationCompleted_v1"

    /// 旧データを書き込む App Group 内のディレクトリ。entitlement が無ければ nil。
    private var baseDir: URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID
        ) else { return nil }
        return container.appendingPathComponent(SharedConstants.storageDirectoryName)
    }

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        try resetEnvironment()
    }

    override func tearDown() async throws {
        try resetEnvironment()
        try await super.tearDown()
    }

    /// CoreData・移行フラグ・旧ファイルをまっさらにして各テストを独立させる。
    private func resetEnvironment() throws {
        try? ClipboardStorageManager.shared.clearAll()
        SharedConstants.sharedDefaults?.removeObject(forKey: migrationKey)
        guard let baseDir else { return }
        for name in ["items.json", "trash.json"] {
            try? FileManager.default.removeItem(at: baseDir.appendingPathComponent(name))
        }
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
    }

    // MARK: - Helpers

    /// 旧 JSON 形式（LegacyMetadata 互換）にエンコードできる最小モデル。
    private struct LegacyItemFixture: Codable {
        let id: UUID
        let timestamp: Date
        let type: String
        var isFavorite: Bool = false
        var textContent: String?
        var deletedAt: Date?
    }

    private func legacyJSONData(_ items: [LegacyItemFixture]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(items)
    }

    private func write(_ data: Data, to fileName: String) throws -> URL {
        let dir = try XCTUnwrap(baseDir, "App Group container is unavailable")
        let url = dir.appendingPathComponent(fileName)
        try data.write(to: url)
        return url
    }

    private func textItem(_ text: String, deletedAt: Date? = nil) -> LegacyItemFixture {
        LegacyItemFixture(
            id: UUID(),
            timestamp: Date(),
            type: "text",
            textContent: text,
            deletedAt: deletedAt
        )
    }

    private func skipIfNoContainer() throws {
        if baseDir == nil {
            throw XCTSkip("App Group container unavailable in this test environment")
        }
    }

    // MARK: - Tests

    func testMigrateIfNeeded_withLegacyData_migratesSuccessfully() async throws {
        try skipIfNoContainer()

        let items = [textItem("alpha"), textItem("beta")]
        let trash = [textItem("trashed", deletedAt: Date())]
        _ = try write(try legacyJSONData(items), to: "items.json")
        _ = try write(try legacyJSONData(trash), to: "trash.json")

        await JSONMigration.migrateIfNeeded()

        let migratedItems = try await ClipboardStorageManager.shared.load()
        let migratedTrash = try await ClipboardStorageManager.shared.loadTrash()

        XCTAssertEqual(Set(migratedItems.compactMap { $0.textContent }), ["alpha", "beta"],
                       "全アイテムが欠落なく移行されること")
        XCTAssertEqual(migratedTrash.compactMap { $0.textContent }, ["trashed"],
                       "ゴミ箱データも移行されること")
        XCTAssertTrue(SharedConstants.sharedDefaults?.bool(forKey: migrationKey) ?? false,
                      "移行完了フラグが立つこと")
    }

    func testMigrateIfNeeded_deletesLegacyFilesAfterSuccess() async throws {
        try skipIfNoContainer()

        let itemsURL = try write(try legacyJSONData([textItem("x")]), to: "items.json")

        await JSONMigration.migrateIfNeeded()

        XCTAssertFalse(FileManager.default.fileExists(atPath: itemsURL.path),
                       "移行成功後は旧 JSON ファイルが削除されること")
    }

    func testMigrateIfNeeded_withEncryptedData_decryptsCorrectly() async throws {
        try skipIfNoContainer()

        let plain = try legacyJSONData([textItem("secret-payload")])
        let encrypted: Data
        do {
            encrypted = try EncryptionHelper.encrypt(plain)
        } catch {
            throw XCTSkip("Keychain unavailable, cannot prepare encrypted fixture: \(error)")
        }
        _ = try write(encrypted, to: "items.json")

        await JSONMigration.migrateIfNeeded()

        let migrated = try await ClipboardStorageManager.shared.load()
        XCTAssertEqual(migrated.compactMap { $0.textContent }, ["secret-payload"],
                       "暗号化された旧データも復号して移行されること（暗号往復）")
    }

    func testMigrateIfNeeded_withCorruptedData_handlesGracefully() async throws {
        try skipIfNoContainer()

        // 復号もデコードもできないゴミデータ
        _ = try write(Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01]), to: "items.json")

        // クラッシュせず完了すること
        await JSONMigration.migrateIfNeeded()

        let migrated = try await ClipboardStorageManager.shared.load()
        XCTAssertTrue(migrated.isEmpty, "破損データからは何も移行されないこと（データ生成されないこと）")
    }

    func testMigrateIfNeeded_whenAlreadyMigrated_skipsRerun() async throws {
        try skipIfNoContainer()

        // 既に移行済みフラグを立てた状態で旧ファイルを置く
        SharedConstants.sharedDefaults?.set(true, forKey: migrationKey)
        let itemsURL = try write(try legacyJSONData([textItem("should-not-migrate")]), to: "items.json")

        await JSONMigration.migrateIfNeeded()

        let migrated = try await ClipboardStorageManager.shared.load()
        XCTAssertTrue(migrated.isEmpty, "移行済みなら再移行しないこと")
        XCTAssertTrue(FileManager.default.fileExists(atPath: itemsURL.path),
                      "移行済みなら旧ファイルを削除しない（既存データを保持する）こと")
    }
}
