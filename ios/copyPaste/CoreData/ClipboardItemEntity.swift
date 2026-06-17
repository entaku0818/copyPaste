import CoreData
import Foundation

@objc(ClipboardItemEntity)
class ClipboardItemEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var timestamp: Date?
    @NSManaged var typeRaw: String?
    @NSManaged var isFavorite: Bool
    @NSManaged var isInTrash: Bool
    @NSManaged var deletedAt: Date?
    @NSManaged var textContent: String?
    @NSManaged var imageData: Data?
    @NSManaged var imageThumbnailData: Data?
    @NSManaged var urlString: String?
    @NSManaged var fileName: String?
    @NSManaged var fileSize: Int64
    @NSManaged var categoryRaw: String?
    @NSManaged var ocrText: String?
}

extension ClipboardItemEntity {
    static func fetchRequest() -> NSFetchRequest<ClipboardItemEntity> {
        NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
    }

    func configure(from item: ClipboardItem, isInTrash: Bool = false) {
        self.id = item.id
        self.timestamp = item.timestamp
        self.typeRaw = item.type.rawValue
        self.isFavorite = item.isFavorite
        self.isInTrash = isInTrash
        self.deletedAt = item.deletedAt
        self.textContent = item.textContent
        self.imageData = item.imageData
        self.imageThumbnailData = item.imageThumbnailData
        self.urlString = item.url?.absoluteString
        self.fileName = item.fileName
        self.fileSize = item.fileSize ?? 0
        self.categoryRaw = item.category?.rawValue
        self.ocrText = item.ocrText
    }

    func toClipboardItem() -> ClipboardItem? {
        guard
            let id = id,
            let timestamp = timestamp,
            let typeRaw = typeRaw,
            let type = ClipboardItemType(rawValue: typeRaw)
        else { return nil }

        var item = ClipboardItem(
            id: id,
            timestamp: timestamp,
            type: type,
            isFavorite: isFavorite,
            textContent: textContent,
            imageData: imageData,
            imageThumbnailData: imageThumbnailData,
            url: urlString.flatMap { URL(string: $0) },
            fileName: fileName,
            fileSize: fileSize == 0 ? nil : fileSize,
            category: categoryRaw.flatMap { ItemCategory(rawValue: $0) },
            ocrText: ocrText
        )
        item.deletedAt = deletedAt
        return item
    }
}
