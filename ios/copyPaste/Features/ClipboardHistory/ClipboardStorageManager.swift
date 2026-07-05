import CoreData
import Foundation
import OSLog

class ClipboardStorageManager {
    static let shared = ClipboardStorageManager()
    private let logger = Logger(subsystem: "com.clipkit", category: "Storage")

    private init() {}

    // MARK: - Save

    func save(items: [ClipboardItem]) async throws {
        await PersistenceController.shared.waitUntilLoaded()
        let ctx = PersistenceController.shared.newBackgroundContext()
        try await ctx.perform {
            // 既存アイテムを取得して upsert（削除対象は消す）
            let request = ClipboardItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isInTrash == NO")
            let existing = try ctx.fetch(request)
            let existingByID = Dictionary(
                existing.compactMap { e -> (UUID, ClipboardItemEntity)? in
                    guard let id = e.id else { return nil }
                    return (id, e)
                },
                uniquingKeysWith: { first, _ in first }
            )
            let newIDs = Set(items.map { $0.id })
            for (id, entity) in existingByID where !newIDs.contains(id) {
                ctx.delete(entity)
            }
            for item in items {
                let entity = existingByID[item.id] ?? ClipboardItemEntity(context: ctx)
                entity.configure(from: item, isInTrash: false)
            }
            try ctx.save()
        }
        logger.info("Saved \(items.count) items")
    }

    // MARK: - Load

    func load() async throws -> [ClipboardItem] {
        await PersistenceController.shared.waitUntilLoaded()
        let ctx = PersistenceController.shared.newBackgroundContext()
        return try await ctx.perform {
            let request = ClipboardItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isInTrash == NO")
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            return try ctx.fetch(request).compactMap { $0.toClipboardItem() }
        }
    }

    // MARK: - Trash

    func saveTrash(items: [ClipboardItem]) async throws {
        await PersistenceController.shared.waitUntilLoaded()
        let ctx = PersistenceController.shared.newBackgroundContext()
        try await ctx.perform {
            let request = ClipboardItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isInTrash == YES")
            let existing = try ctx.fetch(request)
            let existingByID = Dictionary(
                existing.compactMap { e -> (UUID, ClipboardItemEntity)? in
                    guard let id = e.id else { return nil }
                    return (id, e)
                },
                uniquingKeysWith: { first, _ in first }
            )
            let newIDs = Set(items.map { $0.id })
            for (id, entity) in existingByID where !newIDs.contains(id) {
                ctx.delete(entity)
            }
            for item in items {
                let entity = existingByID[item.id] ?? ClipboardItemEntity(context: ctx)
                entity.configure(from: item, isInTrash: true)
            }
            try ctx.save()
        }
    }

    func loadTrash() async throws -> [ClipboardItem] {
        await PersistenceController.shared.waitUntilLoaded()
        let ctx = PersistenceController.shared.newBackgroundContext()
        return try await ctx.perform {
            let request = ClipboardItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isInTrash == YES")
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            return try ctx.fetch(request).compactMap { $0.toClipboardItem() }
        }
    }

    // MARK: - Delete

    func deleteItem(_ item: ClipboardItem) throws {
        try batchDelete(predicate: NSPredicate(format: "id == %@", item.id as CVarArg))
    }

    /// ゴミ箱内の全アイテムを単一トランザクションで削除する。
    /// 個別削除（N+1）ではなく NSBatchDeleteRequest を使う。
    func emptyTrash() throws {
        try batchDelete(predicate: NSPredicate(format: "isInTrash == YES"))
        logger.info("Emptied trash via batch delete")
    }

    func clearAll() throws {
        try batchDelete(predicate: nil)
    }

    /// predicate に合致するエンティティを NSBatchDeleteRequest で一括削除する。
    /// メインスレッドの viewContext ではなくバックグラウンドコンテキストを使い、
    /// 削除結果（objectID）を viewContext にマージして UI 表示と整合させる。
    private func batchDelete(predicate: NSPredicate?) throws {
        let ctx = PersistenceController.shared.newBackgroundContext()
        var caughtError: Error?
        ctx.performAndWait {
            do {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ClipboardItemEntity")
                fetchRequest.predicate = predicate
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                deleteRequest.resultType = .resultTypeObjectIDs
                let result = try ctx.execute(deleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID], !objectIDs.isEmpty {
                    // バッチ削除は永続ストアを直接更新するため、メモリ上のコンテキストへ手動で反映する
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                        into: [PersistenceController.shared.viewContext]
                    )
                }
            } catch {
                caughtError = error
            }
        }
        if let caughtError { throw caughtError }
    }

    // MARK: - Storage Info（CoreData では目安のみ）

    func getTotalStorageSize() throws -> Int64 { 0 }
    func checkStorageLimit() async throws {}
}
