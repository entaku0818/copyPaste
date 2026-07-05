import CoreData
import Foundation
import OSLog

/// スニペット（定型文）のCoreData I/O。
/// ClipboardStorageManagerと同じApp Group共有ストアを使い、キーボード拡張からも読める。
class SnippetStorageManager {
    static let shared = SnippetStorageManager()
    private let logger = Logger(subsystem: "com.clipkit", category: "SnippetStorage")

    private init() {}

    /// 現在の一覧で全置換するupsert（削除・並び替えもこの1本で永続化する）
    func save(snippets: [Snippet]) async throws {
        try await PersistenceController.shared.performBackgroundTask { ctx in
            let request = SnippetEntity.fetchRequest()
            let existing = try ctx.fetch(request)
            let existingByID = Dictionary(
                existing.compactMap { e -> (UUID, SnippetEntity)? in
                    guard let id = e.id else { return nil }
                    return (id, e)
                },
                uniquingKeysWith: { first, _ in first }
            )
            let newIDs = Set(snippets.map { $0.id })
            for (id, entity) in existingByID where !newIDs.contains(id) {
                ctx.delete(entity)
            }
            for snippet in snippets {
                let entity = existingByID[snippet.id] ?? SnippetEntity(context: ctx)
                entity.configure(from: snippet)
            }
            try ctx.save()
        }
        logger.info("Saved \(snippets.count) snippets")
    }

    func load() async throws -> [Snippet] {
        try await PersistenceController.shared.performBackgroundTask { ctx in
            let request = SnippetEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "sortOrder", ascending: true),
                NSSortDescriptor(key: "createdAt", ascending: true)
            ]
            return try ctx.fetch(request).compactMap { $0.toSnippet() }
        }
    }
}
