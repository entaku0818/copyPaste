import Foundation
import OSLog

/// ローカルストレージとCloudKitを束ねるリポジトリ層
final class ClipboardRepository {
    static let shared = ClipboardRepository()

    private let local = ClipboardStorageManager.shared
    private let cloud = CloudKitSyncManager.shared
    private let logger = Logger(subsystem: "com.clipkit", category: "Repository")

    private var syncMode: CloudKitSyncMode { CloudKitSyncMode.current }

    // MARK: - Load（ローカル + CloudKit差分マージ）

    func load() async throws -> [ClipboardItem] {
        var items = try await local.load()

        if syncMode.isEnabled {
            do {
                let remoteItems = try await cloud.fetchAll(mode: syncMode)
                items = merge(local: items, remote: remoteItems)
                // マージ結果をローカルに反映
                try await local.save(items: items)
            } catch {
                logger.warning("CloudKit fetch failed, using local only: \(error.localizedDescription)")
            }
        }

        return items
    }

    // MARK: - Save（ローカル保存 + CloudKit同期）

    func save(items: [ClipboardItem]) async throws {
        try await local.save(items: items)
    }

    func saveAndSync(item: ClipboardItem) async throws {
        // 個別アイテムの追加・更新時はCloudKitにも即時同期
        if syncMode.isEnabled {
            await cloud.upload(item: item, mode: syncMode)
        }
    }

    // MARK: - Trash

    func loadTrash() async throws -> [ClipboardItem] {
        return (try? await local.loadTrash()) ?? []
    }

    func saveTrash(items: [ClipboardItem]) async throws {
        try? await local.saveTrash(items: items)
    }

    // MARK: - Delete

    func deleteItem(_ item: ClipboardItem) throws {
        try? local.deleteItem(item)
        if syncMode.isEnabled {
            Task { await cloud.delete(itemID: item.id) }
        }
    }

    func clearAll() throws {
        try local.clearAll()
        if syncMode.isEnabled {
            Task { await cloud.deleteAll() }
        }
    }

    // MARK: - Merge

    private func merge(local: [ClipboardItem], remote: [ClipboardItem]) -> [ClipboardItem] {
        var merged: [UUID: ClipboardItem] = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for remoteItem in remote {
            if let localItem = merged[remoteItem.id] {
                // 新しい方を採用
                if remoteItem.timestamp > localItem.timestamp {
                    merged[remoteItem.id] = remoteItem
                }
            } else {
                merged[remoteItem.id] = remoteItem
            }
        }
        return Array(merged.values)
    }
}
