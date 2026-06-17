import CoreData
import OSLog

final class PersistenceController {
    // 拡張機能（keyboard/widget）は .appex バンドルで動くため CloudKit 同期なし
    private static let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")
    // テスト実行中は in-memory store を使い高速化・副作用なしにする
    private static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    static let shared = PersistenceController(
        useCloudKit: !isExtension && !isRunningTests,
        inMemory: isRunningTests
    )

    private let logger = Logger(subsystem: "com.clipkit", category: "Persistence")
    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(useCloudKit: Bool = true, inMemory: Bool = false) {
        if useCloudKit {
            container = NSPersistentCloudKitContainer(name: "ClipboardDataModel")
        } else {
            container = NSPersistentContainer(name: "ClipboardDataModel")
        }

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            guard let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID
            ) else {
                logger.error("App Group container not found")
                container.loadPersistentStores { _, _ in }
                return
            }

            let storeURL = groupURL.appendingPathComponent("ClipboardData.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)

            if useCloudKit {
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: "iCloud.com.entaku.clipkit"
                )
            }

            // 拡張機能がメインアプリの変更を受け取るために必要
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(
                true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
            )
            // v1 → v2 自動マイグレーション（categoryRaw/ocrText フィールド追加）
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            // NSFileProtection: デバイスロック中でも拡張機能が読めるよう CompleteUnlessOpen を使用
            description.setOption(
                FileProtectionType.completeUnlessOpen as NSObject,
                forKey: NSPersistentStoreFileProtectionKey
            )

            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { [weak self] _, error in
            if let error {
                self?.logger.error("CoreData load failed: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }
}
