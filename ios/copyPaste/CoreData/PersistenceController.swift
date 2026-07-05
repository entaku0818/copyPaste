import CoreData
import OSLog

final class PersistenceController {
    // 拡張機能（keyboard/widget）は .appex バンドルで動くため CloudKit 同期なし
    private static let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")
    // テスト実行中は in-memory store を使い高速化・副作用なしにする
    private static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    static let shared = PersistenceController(
        useCloudKit: !isExtension && !isRunningTests && CloudKitSyncMode.current.isEnabled,
        inMemory: isRunningTests
    )

    private let logger = Logger(subsystem: "com.clipkit", category: "Persistence")
    private let container: NSPersistentContainer

    /// テスト用途: 実際に使われているコンテナがCloudKit対応かどうかを確認するため。
    /// CoreDataの読み書きには使わないこと（performBackgroundTask経由で行う）。
    var isUsingCloudKit: Bool { container is NSPersistentCloudKitContainer }

    // MARK: - Store Loading Gate

    // loadPersistentStores は非同期のため、読み込み完了前に保存/読み込みを行うと
    // 「NSPersistentStoreCoordinator has no persistent stores」という
    // Swiftのdo/catchで捕捉できないNSException（即クラッシュ）が発生する。
    // CoreDataを触る前に必ず waitUntilLoaded() を待つこと。
    private let stateLock = NSLock()
    private var isStoreLoaded = false
    private var pendingContinuations: [CheckedContinuation<Void, Never>] = []

    private func markStoreLoaded() {
        stateLock.lock()
        isStoreLoaded = true
        let continuations = pendingContinuations
        pendingContinuations.removeAll()
        stateLock.unlock()
        continuations.forEach { $0.resume() }
    }

    /// 永続ストアの読み込み完了を待つ（読み込み失敗時もエラーはログ済みとしてresumeする）。
    func waitUntilLoaded() async {
        await withCheckedContinuation { continuation in
            stateLock.lock()
            if isStoreLoaded {
                stateLock.unlock()
                continuation.resume()
                return
            }
            pendingContinuations.append(continuation)
            stateLock.unlock()
        }
    }

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
            self?.markStoreLoaded()
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Safe Access

    // newBackgroundContext/viewContext は意図的に外部非公開にしている。
    // CoreDataの読み書きは必ず performBackgroundTask(_:) 経由で行うこと。
    // こうすることで「ストア読み込み完了を待たずにアクセスする」という
    // 今回の即クラッシュと同じ書き方が、新しく増えてもコンパイルエラーになる。

    private func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }

    /// ストア読み込み完了を待ってから背景コンテキストで処理を実行する。
    /// CoreDataへのアクセスは必ずこのメソッド経由で行うこと。
    @discardableResult
    func performBackgroundTask<T: Sendable>(
        _ body: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        await waitUntilLoaded()
        let ctx = newBackgroundContext()
        return try await ctx.perform {
            try body(ctx)
        }
    }

    /// NSBatchDeleteRequestの削除結果（objectID）をviewContextへ反映する。
    /// バッチ削除は永続ストアを直接更新するため、メモリ上のコンテキストへの
    /// 手動マージが必要（UI表示との整合性のため）。
    func mergeDeletedObjectIDs(_ objectIDs: [NSManagedObjectID]) {
        guard !objectIDs.isEmpty else { return }
        NSManagedObjectContext.mergeChanges(
            fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
            into: [container.viewContext]
        )
    }
}
