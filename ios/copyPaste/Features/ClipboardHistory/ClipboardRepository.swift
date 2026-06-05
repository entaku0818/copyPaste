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
        do {
            return try await local.loadTrash()
        } catch {
            logger.error("Failed to load trash: \(error.localizedDescription)")
            return []
        }
    }

    func saveTrash(items: [ClipboardItem]) async throws {
        do {
            try await local.saveTrash(items: items)
        } catch {
            logger.error("Failed to save trash: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Delete

    func deleteItem(_ item: ClipboardItem) throws {
        do {
            try local.deleteItem(item)
        } catch {
            logger.error("Failed to delete item: \(error.localizedDescription)")
            throw error
        }
    }

    func clearAll() throws {
        try local.clearAll()
    }

    /// ゴミ箱内の全アイテムを一括削除する（NSBatchDeleteRequest）。
    func emptyTrash() throws {
        do {
            try local.emptyTrash()
        } catch {
            logger.error("Failed to empty trash: \(error.localizedDescription)")
            throw error
        }
    }
}
