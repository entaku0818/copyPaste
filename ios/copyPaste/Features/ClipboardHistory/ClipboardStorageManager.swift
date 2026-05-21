import CoreData
import Foundation
import OSLog

class ClipboardStorageManager {
    static let shared = ClipboardStorageManager()
    private let logger = Logger(subsystem: "com.clipkit", category: "Storage")

    private init() {}

    // MARK: - Save

    func save(items: [ClipboardItem]) async throws {
        let ctx = PersistenceController.shared.newBackgroundContext()
        try await ctx.perform {
            // 既存アイテムを取得して upsert（削除対象は消す）
            let request = ClipboardItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isInTrash == NO")
            let existing = try ctx.fetch(request)
            let existingByID = Dictionary(
                uniqueKeysWithValues: existing.compactMap { e -> (UUID, ClipboardItemEntity)? in
                    guard let id = e.id else { return nil }
                    return (id, e)
                }
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
        let ctx = PersistenceController.shared.newBackgroundContext()
        try await ctx.perform {
            let request = ClipboardItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isInTrash == YES")
            let existing = try ctx.fetch(request)
            let existingByID = Dictionary(
                uniqueKeysWithValues: existing.compactMap { e -> (UUID, ClipboardItemEntity)? in
                    guard let id = e.id else { return nil }
                    return (id, e)
                }
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
        let ctx = PersistenceController.shared.viewContext
        let request = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        guard let entity = try ctx.fetch(request).first else { return }
        ctx.delete(entity)
        try ctx.save()
    }

    func clearAll() throws {
        let ctx = PersistenceController.shared.viewContext
        let request = ClipboardItemEntity.fetchRequest()
        let entities = (try? ctx.fetch(request)) ?? []
        entities.forEach { ctx.delete($0) }
        try ctx.save()
    }

    // MARK: - Storage Info（CoreData では目安のみ）

    func getTotalStorageSize() throws -> Int64 { 0 }
    func checkStorageLimit() async throws {}
}
