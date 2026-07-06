import CoreData
import OSLog

enum PersistenceError: LocalizedError {
    case storeNotAvailable

    var errorDescription: String? {
        "CoreData永続ストアが利用できません（読み込み失敗、または未完了）"
    }
}

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
    // ストア読み込みにかかった時間を計測するための基準時刻（診断ログ用）
    private let createdAt = ProcessInfo.processInfo.systemUptime

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

    private func markStoreLoaded(error: Error?) {
        let elapsed = ProcessInfo.processInfo.systemUptime - createdAt
        let elapsedStr = String(format: "%.2f", elapsed)
        if let error {
            let nsError = error as NSError
            let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
            let detailed = nsError.userInfo[NSDetailedErrorsKey] as? [NSError]
            let failureReason = nsError.localizedFailureReason
                ?? (nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String)
            logger.error("""
                Store load finished with error after \(elapsedStr)s: \
                domain=\(nsError.domain) code=\(nsError.code) \
                description=\(nsError.localizedDescription) \
                failureReason=\(failureReason ?? "nil") \
                underlying=\(underlying.map { "\($0.domain)/\($0.code): \($0.localizedDescription)" } ?? "nil") \
                detailed=\(detailed?.map { "\($0.domain)/\($0.code): \($0.localizedDescription)" } ?? []) \
                userInfo=\(nsError.userInfo)
                """)
        } else {
            logger.info("Store loaded successfully after \(elapsedStr)s")
        }

        stateLock.lock()
        isStoreLoaded = true
        let continuations = pendingContinuations
        pendingContinuations.removeAll()
        stateLock.unlock()
        continuations.forEach { $0.resume() }
    }

    /// 永続ストアの読み込み完了を待つ（読み込み失敗時もエラーはログ済みとしてresumeする）。
    func waitUntilLoaded() async {
        let waitStart = ProcessInfo.processInfo.systemUptime
        var hadToWait = false
        await withCheckedContinuation { continuation in
            stateLock.lock()
            if isStoreLoaded {
                stateLock.unlock()
                continuation.resume()
                return
            }
            hadToWait = true
            pendingContinuations.append(continuation)
            stateLock.unlock()
        }
        if hadToWait {
            let elapsed = ProcessInfo.processInfo.systemUptime - waitStart
            logger.info("waitUntilLoaded: caller waited \(String(format: "%.2f", elapsed))s for store to load")
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
                // markStoreLoaded()を呼ばないとwaitUntilLoaded()が永久に
                // ハングしてしまうため、失敗時も必ず呼ぶ。
                container.loadPersistentStores { [weak self] _, error in
                    self?.markStoreLoaded(error: error)
                }
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

        logger.info(
            "Loading persistent store... (isExtension=\(Self.isExtension), useCloudKit=\(useCloudKit), inMemory=\(inMemory))"
        )
        container.loadPersistentStores { [weak self] _, error in
            self?.markStoreLoaded(error: error)
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
    ///
    /// waitUntilLoaded()のフラグだけに頼らず、実際に
    /// persistentStoreCoordinator にストアが登録されているかを直接確認する。
    /// こうすることで、万一何らかの理由で読み込みが失敗/未完了のまま
    /// 通過してしまっても、ctx.save()が投げる捕捉不可能なNSException
    /// （即クラッシュ）ではなく、捕捉可能なSwiftのErrorとして安全に弾ける。
    /// この経路に入った場合はos.Loggerに発生時の状況
    /// （経過時間・CloudKit有無・ストア構成）を残す。
    @discardableResult
    func performBackgroundTask<T: Sendable>(
        _ body: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        await waitUntilLoaded()
        guard !container.persistentStoreCoordinator.persistentStores.isEmpty else {
            let elapsed = ProcessInfo.processInfo.systemUptime - createdAt
            let descriptions = container.persistentStoreDescriptions.map { $0.url?.lastPathComponent ?? "nil" }
            let message = "performBackgroundTask: no persistent stores after waitUntilLoaded() "
                + "(elapsed=\(String(format: "%.2f", elapsed))s, isExtension=\(Self.isExtension), "
                + "isUsingCloudKit=\(isUsingCloudKit), descriptions=\(descriptions))"
            logger.error("\(message)")
            throw PersistenceError.storeNotAvailable
        }
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
