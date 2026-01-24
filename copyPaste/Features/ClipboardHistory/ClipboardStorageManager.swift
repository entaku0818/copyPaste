import Foundation
import OSLog

class ClipboardStorageManager {
    static let shared = ClipboardStorageManager()
    private let logger = Logger(subsystem: "com.copyPaste", category: "Storage")

    private let fileManager = FileManager.default
    private let baseDirectory: URL
    private let metadataFileName = "items.json"

    // ストレージ制限
    private let maxStorageSize: Int64 = 100 * 1024 * 1024 // 100MB

    private init() {
        // Documentsディレクトリ内にClipboardHistoryフォルダを作成
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        baseDirectory = documentsDirectory.appendingPathComponent("ClipboardHistory", isDirectory: true)

        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            do {
                try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
                logger.info("Created clipboard history directory")
            } catch {
                logger.error("Failed to create directory: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Save

    func save(items: [ClipboardItem]) async throws {
        logger.info("Saving \(items.count) items...")

        // 画像データを別ファイルとして保存し、メタデータのみ保存
        var itemsToSave: [ClipboardItemMetadata] = []

        for item in items {
            var metadata = ClipboardItemMetadata(
                id: item.id,
                timestamp: item.timestamp,
                type: item.type,
                textContent: item.textContent,
                url: item.url,
                fileName: item.fileName,
                fileSize: item.fileSize,
                fileURL: item.fileURL
            )

            // 画像データを別ファイルに保存
            if let imageData = item.imageData {
                let imageFileName = "\(item.id.uuidString)_image.dat"
                let imageURL = baseDirectory.appendingPathComponent(imageFileName)
                try imageData.write(to: imageURL)
                metadata.imageFileName = imageFileName
            }

            if let thumbnailData = item.imageThumbnailData {
                let thumbnailFileName = "\(item.id.uuidString)_thumbnail.dat"
                let thumbnailURL = baseDirectory.appendingPathComponent(thumbnailFileName)
                try thumbnailData.write(to: thumbnailURL)
                metadata.thumbnailFileName = thumbnailFileName
            }

            itemsToSave.append(metadata)
        }

        // メタデータをJSONで保存
        let metadataURL = baseDirectory.appendingPathComponent(metadataFileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(itemsToSave)
        try data.write(to: metadataURL)

        logger.info("Successfully saved \(items.count) items")
    }

    // MARK: - Load

    func load() async throws -> [ClipboardItem] {
        logger.info("Loading items...")

        let metadataURL = baseDirectory.appendingPathComponent(metadataFileName)

        // ファイルが存在しない場合は空配列を返す
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            logger.info("No saved items found")
            return []
        }

        // メタデータを読み込み
        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadataList = try decoder.decode([ClipboardItemMetadata].self, from: data)

        // ClipboardItemに変換
        var items: [ClipboardItem] = []

        for metadata in metadataList {
            var imageData: Data?
            var thumbnailData: Data?

            // 画像データを読み込み
            if let imageFileName = metadata.imageFileName {
                let imageURL = baseDirectory.appendingPathComponent(imageFileName)
                if fileManager.fileExists(atPath: imageURL.path) {
                    imageData = try? Data(contentsOf: imageURL)
                }
            }

            if let thumbnailFileName = metadata.thumbnailFileName {
                let thumbnailURL = baseDirectory.appendingPathComponent(thumbnailFileName)
                if fileManager.fileExists(atPath: thumbnailURL.path) {
                    thumbnailData = try? Data(contentsOf: thumbnailURL)
                }
            }

            let item = ClipboardItem(
                id: metadata.id,
                timestamp: metadata.timestamp,
                type: metadata.type,
                textContent: metadata.textContent,
                imageData: imageData,
                imageThumbnailData: thumbnailData,
                url: metadata.url,
                fileName: metadata.fileName,
                fileSize: metadata.fileSize,
                fileURL: metadata.fileURL
            )

            items.append(item)
        }

        logger.info("Successfully loaded \(items.count) items")
        return items
    }

    // MARK: - Delete

    func deleteItem(_ item: ClipboardItem) throws {
        // 画像ファイルを削除
        if item.imageData != nil {
            let imageFileName = "\(item.id.uuidString)_image.dat"
            let imageURL = baseDirectory.appendingPathComponent(imageFileName)
            try? fileManager.removeItem(at: imageURL)
        }

        if item.imageThumbnailData != nil {
            let thumbnailFileName = "\(item.id.uuidString)_thumbnail.dat"
            let thumbnailURL = baseDirectory.appendingPathComponent(thumbnailFileName)
            try? fileManager.removeItem(at: thumbnailURL)
        }
    }

    func clearAll() throws {
        logger.info("Clearing all items...")

        // ディレクトリ内のすべてのファイルを削除
        let contents = try fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)
        for url in contents {
            try fileManager.removeItem(at: url)
        }

        logger.info("Successfully cleared all items")
    }

    // MARK: - Storage Info

    func getTotalStorageSize() throws -> Int64 {
        let contents = try fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: [.fileSizeKey])

        var totalSize: Int64 = 0
        for url in contents {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }

        return totalSize
    }

    func checkStorageLimit() async throws {
        let totalSize = try getTotalStorageSize()

        if totalSize > self.maxStorageSize {
            logger.warning("Storage limit exceeded: \(totalSize) bytes (limit: \(self.maxStorageSize) bytes)")
            // TODO: 古いアイテムを自動削除
        }
    }
}

// MARK: - Metadata Model

private struct ClipboardItemMetadata: Codable {
    let id: UUID
    let timestamp: Date
    let type: ClipboardItemType

    var textContent: String?
    var imageFileName: String?
    var thumbnailFileName: String?
    var url: URL?
    var fileName: String?
    var fileSize: Int64?
    var fileURL: URL?
}
