import CoreData
import Foundation

@objc(SnippetEntity)
class SnippetEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var content: String?
    @NSManaged var sortOrder: Int64
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
}

extension SnippetEntity {
    static func fetchRequest() -> NSFetchRequest<SnippetEntity> {
        NSFetchRequest<SnippetEntity>(entityName: "SnippetEntity")
    }

    func configure(from snippet: Snippet) {
        self.id = snippet.id
        self.title = snippet.title
        self.content = snippet.content
        self.sortOrder = snippet.sortOrder
        self.createdAt = snippet.createdAt
        self.updatedAt = snippet.updatedAt
    }

    func toSnippet() -> Snippet? {
        guard let id = id else { return nil }
        return Snippet(
            id: id,
            title: title ?? "",
            content: content ?? "",
            sortOrder: sortOrder,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}
