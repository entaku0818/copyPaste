import CoreData
import Foundation
import OSLog

class ClipboardStorageManager {
    static let shared = ClipboardStorageManager()
    private let logger = Logger(subsystem: "com.clipkit", category: "Storage")

    private init() {}

    // MARK: - Save

    /// 渡されたアイテムを upsert する。**渡されなかったレコードは削除しない**（issue #102）。
    ///
    /// 以前は「渡された配列こそが唯一の正しい全体像」という前提で、配列に含まれない
    /// レコードをすべて削除していた。しかし呼び出し元の `state.items` は
    /// CloudKit で他端末から届いた変更を反映していない古いスナップショットになりうるため、
    /// 他端末のアイテムを削除し、その削除がCloudKit経由で相手端末にも伝播していた。
    ///
    /// 削除は「ユーザーの明示的な削除操作」と「履歴上限のプルーニング」から
    /// 対象IDを指定して行う（`deleteItem` / `clearAll` / `emptyTrash`）。
    func save(items: [ClipboardItem]) async throws {
        try await upsert(items: items, isInTrash: false)
        logger.info("Upserted \(items.count) items")
    }

    // MARK: - Load

    func load() async throws -> [ClipboardItem] {
        try await PersistenceController.shared.performBackgroundTask { ctx in
            let request = ClipboardItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isInTrash == NO")
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            return try ctx.fetch(request).compactMap { $0.toClipboardItem() }
        }
    }

    // MARK: - Trash

    /// ゴミ箱側の upsert。`save(items:)` と同じく渡されなかったレコードは削除しない。
    func saveTrash(items: [ClipboardItem]) async throws {
        try await upsert(items: items, isInTrash: true)
    }

    /// ID一致で upsert する共通処理。
    ///
    /// 既存レコードの検索は `isInTrash` で絞らず**全レコードを対象**にする。
    /// これにより「履歴 → ゴミ箱」「ゴミ箱 → 復元」の移動が、
    /// 同じIDのエンティティの `isInTrash` を書き換えるだけで成立する
    /// （絞ってしまうと同じIDのレコードが履歴側とゴミ箱側に二重に作られる）。
    private func upsert(items: [ClipboardItem], isInTrash: Bool) async throws {
        guard !items.isEmpty else { return }
        try await PersistenceController.shared.performBackgroundTask { ctx in
            let request = ClipboardItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", items.map { $0.id })
            let existing = try ctx.fetch(request)
            let existingByID = Dictionary(
                existing.compactMap { e -> (UUID, ClipboardItemEntity)? in
                    guard let id = e.id else { return nil }
                    return (id, e)
                },
                uniquingKeysWith: { first, _ in first }
            )
            for item in items {
                let entity = existingByID[item.id] ?? ClipboardItemEntity(context: ctx)
                entity.configure(from: item, isInTrash: isInTrash)
            }
            try ctx.save()
        }
    }

    func loadTrash() async throws -> [ClipboardItem] {
        try await PersistenceController.shared.performBackgroundTask { ctx in
            let request = ClipboardItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isInTrash == YES")
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            return try ctx.fetch(request).compactMap { $0.toClipboardItem() }
        }
    }

    // MARK: - Delete

    func deleteItem(_ item: ClipboardItem) async throws {
        try await batchDelete(predicate: NSPredicate(format: "id == %@", item.id as CVarArg))
    }

    /// ゴミ箱内の全アイテムを単一トランザクションで削除する。
    /// 個別削除（N+1）ではなく NSBatchDeleteRequest を使う。
    func emptyTrash() async throws {
        try await batchDelete(predicate: NSPredicate(format: "isInTrash == YES"))
        logger.info("Emptied trash via batch delete")
    }

    func clearAll() async throws {
        try await batchDelete(predicate: nil)
    }

    /// predicate に合致するエンティティを NSBatchDeleteRequest で一括削除する。
    private func batchDelete(predicate: NSPredicate?) async throws {
        try await PersistenceController.shared.performBackgroundTask { ctx in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ClipboardItemEntity")
            fetchRequest.predicate = predicate
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            let result = try ctx.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                PersistenceController.shared.mergeDeletedObjectIDs(objectIDs)
            }
        }
    }

    // MARK: - Storage Info（CoreData では目安のみ）

    func getTotalStorageSize() throws -> Int64 { 0 }
    func checkStorageLimit() async throws {}
}
