import Foundation
import OSLog

/// ローカルCoreDataストレージへのリポジトリ層
/// CloudKit同期は NSPersistentCloudKitContainer が自動で行う
final class ClipboardRepository {
    static let shared = ClipboardRepository()

    private let local = ClipboardStorageManager.shared
    private let logger = Logger(subsystem: "com.clipkit", category: "Repository")

    // MARK: - Load

    func load() async throws -> [ClipboardItem] {
        try await local.load()
    }

    // MARK: - Save

    func save(items: [ClipboardItem]) async throws {
        try await local.save(items: items)
    }

    func saveAndSync(item: ClipboardItem) async throws {
        // NSPersistentCloudKitContainer が自動でCloudKitへ同期するため追加処理不要
    }

    // MARK: - Trash

    func loadTrash() async throws -> [ClipboardItem] {
        (try? await local.loadTrash()) ?? []
    }

    func saveTrash(items: [ClipboardItem]) async throws {
        try? await local.saveTrash(items: items)
    }

    // MARK: - Delete

    func deleteItem(_ item: ClipboardItem) throws {
        try? local.deleteItem(item)
    }

    func clearAll() throws {
        try local.clearAll()
    }
}
