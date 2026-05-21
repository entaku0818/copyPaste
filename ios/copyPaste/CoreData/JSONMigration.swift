import CoreData
import Foundation
import OSLog

enum JSONMigration {
    private static let migrationKey = "coreDataMigrationCompleted_v1"
    private static let logger = Logger(subsystem: "com.clipkit", category: "Migration")

    static func migrateIfNeeded() async {
        guard !(SharedConstants.sharedDefaults?.bool(forKey: migrationKey) ?? false) else { return }
        logger.info("Starting JSON → CoreData migration")

        let items = (try? await loadLegacy(fileName: "items.json")) ?? []
        let trash = (try? await loadLegacy(fileName: "trash.json")) ?? []

        guard !items.isEmpty || !trash.isEmpty else {
            logger.info("No legacy data to migrate")
            SharedConstants.sharedDefaults?.set(true, forKey: migrationKey)
            return
        }

        let ctx = PersistenceController.shared.newBackgroundContext()
        do {
            try await ctx.perform {
                for item in items {
                    let e = ClipboardItemEntity(context: ctx)
                    e.configure(from: item, isInTrash: false)
                }
                for item in trash {
                    let e = ClipboardItemEntity(context: ctx)
                    e.configure(from: item, isInTrash: true)
                }
                try ctx.save()
            }
            logger.info("Migrated \(items.count) items + \(trash.count) trash")
            SharedConstants.sharedDefaults?.set(true, forKey: migrationKey)
            deleteLegacyFiles()
        } catch {
            logger.error("Migration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private static func loadLegacy(fileName: String) async throws -> [ClipboardItem] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID
        ) else { return [] }

        let baseDir = containerURL.appendingPathComponent(SharedConstants.storageDirectoryName)
        let fileURL = baseDir.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        let rawData = try Data(contentsOf: fileURL)
        // EncryptionHelper で暗号化された旧データも復号できるよう試みる
        let data = (try? EncryptionHelper.decrypt(rawData)) ?? rawData

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadataList = try decoder.decode([LegacyMetadata].self, from: data)

        return metadataList.map { m in
            var imageData: Data?
            var thumbnailData: Data?
            if let name = m.imageFileName {
                imageData = try? Data(contentsOf: baseDir.appendingPathComponent(name))
            }
            if let name = m.thumbnailFileName {
                thumbnailData = try? Data(contentsOf: baseDir.appendingPathComponent(name))
            }
            var item = ClipboardItem(
                id: m.id,
                timestamp: m.timestamp,
                type: m.type,
                isFavorite: m.isFavorite,
                textContent: m.textContent,
                imageData: imageData,
                imageThumbnailData: thumbnailData,
                url: m.url,
                fileName: m.fileName,
                fileSize: m.fileSize
            )
            item.deletedAt = m.deletedAt
            return item
        }
    }

    private static func deleteLegacyFiles() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID
        ) else { return }
        let baseDir = containerURL.appendingPathComponent(SharedConstants.storageDirectoryName)
        for name in ["items.json", "trash.json"] {
            try? FileManager.default.removeItem(at: baseDir.appendingPathComponent(name))
        }
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: baseDir, includingPropertiesForKeys: nil
        ) {
            for url in contents where url.pathExtension == "dat" {
                try? FileManager.default.removeItem(at: url)
            }
        }
        logger.info("Legacy files deleted")
    }
}

// MARK: - Legacy JSON model

private struct LegacyMetadata: Codable {
    let id: UUID
    let timestamp: Date
    let type: ClipboardItemType
    var isFavorite: Bool = false
    var textContent: String?
    var imageFileName: String?
    var thumbnailFileName: String?
    var url: URL?
    var fileName: String?
    var fileSize: Int64?
    var fileURL: URL?
    var deletedAt: Date?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        type = try c.decode(ClipboardItemType.self, forKey: .type)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        textContent = try c.decodeIfPresent(String.self, forKey: .textContent)
        imageFileName = try c.decodeIfPresent(String.self, forKey: .imageFileName)
        thumbnailFileName = try c.decodeIfPresent(String.self, forKey: .thumbnailFileName)
        url = try c.decodeIfPresent(URL.self, forKey: .url)
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
        fileSize = try c.decodeIfPresent(Int64.self, forKey: .fileSize)
        fileURL = try c.decodeIfPresent(URL.self, forKey: .fileURL)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, type, isFavorite
        case textContent, imageFileName, thumbnailFileName
        case url, fileName, fileSize, fileURL, deletedAt
    }
}
