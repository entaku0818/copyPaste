import CloudKit
import OSLog

final class CloudKitSyncManager {
    static let shared = CloudKitSyncManager()

    private let container = CKContainer(identifier: "iCloud.com.entaku.clipkit")
    private var database: CKDatabase { container.privateCloudDatabase }
    private let logger = Logger(subsystem: "com.clipkit", category: "CloudKit")
    private let recordType = "ClipboardItem"

    // MARK: - Upload

    func upload(item: ClipboardItem, mode: CloudKitSyncMode) async {
        guard mode.isEnabled else { return }

        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: item.id.uuidString))
        record["timestamp"] = item.timestamp as CKRecordValue
        record["type"] = item.type.rawValue as CKRecordValue
        record["isFavorite"] = (item.isFavorite ? 1 : 0) as CKRecordValue

        switch item.type {
        case .text:
            if let text = item.textContent {
                record["textContent"] = text as CKRecordValue
            }
        case .url:
            if let url = item.url {
                record["urlString"] = url.absoluteString as CKRecordValue
            }
        case .image:
            if mode.includesMedia {
                if let data = item.imageData {
                    record["imageAsset"] = assetFrom(data: data)
                }
                if let data = item.imageThumbnailData {
                    record["thumbnailAsset"] = assetFrom(data: data)
                }
            }
        case .file:
            record["fileName"] = item.fileName as? CKRecordValue
            record["fileSize"] = item.fileSize as? CKRecordValue
        }

        do {
            try await database.save(record)
            logger.info("Uploaded item: \(item.id)")
        } catch {
            logger.error("Upload failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete

    func delete(itemID: UUID) async {
        let recordID = CKRecord.ID(recordName: itemID.uuidString)
        do {
            try await database.deleteRecord(withID: recordID)
            logger.info("Deleted item: \(itemID)")
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // 存在しないレコードの削除は無視
        } catch {
            logger.error("Delete failed: \(error.localizedDescription)")
        }
    }

    func deleteAll() async {
        do {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            let result = try await database.records(matching: query, resultsLimit: 200)
            let ids = result.matchResults.compactMap { try? $0.1.get().recordID }
            if ids.isEmpty { return }
            let (_, errors) = try await database.modifyRecords(saving: [], deleting: ids)
            if !errors.isEmpty {
                logger.error("Some deletes failed: \(errors.count) errors")
            } else {
                logger.info("Deleted all CloudKit records")
            }
        } catch {
            logger.error("DeleteAll failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch

    func fetchAll(mode: CloudKitSyncMode) async throws -> [ClipboardItem] {
        guard mode.isEnabled else { return [] }

        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let result = try await database.records(matching: query, desiredKeys: desiredKeys(for: mode), resultsLimit: 200)

        var items: [ClipboardItem] = []
        for (_, recordResult) in result.matchResults {
            if let record = try? recordResult.get(),
               let item = clipboardItem(from: record) {
                items.append(item)
            }
        }
        logger.info("Fetched \(items.count) items from CloudKit")
        return items
    }

    // MARK: - Private helpers

    private func desiredKeys(for mode: CloudKitSyncMode) -> [String] {
        var keys = ["timestamp", "type", "isFavorite", "textContent", "urlString", "fileName", "fileSize"]
        if mode.includesMedia {
            keys += ["imageAsset", "thumbnailAsset"]
        }
        return keys
    }

    private func assetFrom(data: Data) -> CKAsset? {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        do {
            try data.write(to: url)
            return CKAsset(fileURL: url)
        } catch {
            return nil
        }
    }

    private func clipboardItem(from record: CKRecord) -> ClipboardItem? {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let timestamp = record["timestamp"] as? Date,
            let typeRaw = record["type"] as? String,
            let type = ClipboardItemType(rawValue: typeRaw)
        else { return nil }

        let isFavorite = (record["isFavorite"] as? Int ?? 0) == 1
        let textContent = record["textContent"] as? String
        let urlString = record["urlString"] as? String
        let url = urlString.flatMap { URL(string: $0) }
        let fileName = record["fileName"] as? String
        let fileSize = record["fileSize"] as? Int64

        var imageData: Data?
        var thumbnailData: Data?
        if let asset = record["imageAsset"] as? CKAsset,
           let fileURL = asset.fileURL {
            imageData = try? Data(contentsOf: fileURL)
        }
        if let asset = record["thumbnailAsset"] as? CKAsset,
           let fileURL = asset.fileURL {
            thumbnailData = try? Data(contentsOf: fileURL)
        }

        return ClipboardItem(
            id: id,
            timestamp: timestamp,
            type: type,
            isFavorite: isFavorite,
            textContent: textContent,
            imageData: imageData,
            imageThumbnailData: thumbnailData,
            url: url,
            fileName: fileName,
            fileSize: fileSize
        )
    }
}
