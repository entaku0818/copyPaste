import Foundation
import CoreData
import ComposableArchitecture

// MARK: - PiPClient

// PiP更新をDependency化する。
// reducerテストが実PiPManager（AVPictureInPicture）を触るとテストプロセスが
// クラッシュ・レースするため、テストではno-opに差し替える（issue #91）。
struct PiPClient {
    var updateItems: @Sendable ([ClipboardItem]) async -> Void
    var stopPiP: @Sendable () async -> Void
}

extension PiPClient: DependencyKey {
    static let liveValue = PiPClient(
        updateItems: { items in
            await MainActor.run { PiPManager.shared.updateItems(items) }
        },
        stopPiP: {
            await MainActor.run { PiPManager.shared.stopPiP() }
        }
    )

    static let testValue = PiPClient(
        updateItems: { _ in },
        stopPiP: {}
    )
}

extension DependencyValues {
    var pipClient: PiPClient {
        get { self[PiPClient.self] }
        set { self[PiPClient.self] = newValue }
    }
}

// MARK: - ClipboardRepositoryClient

// CoreData I/O（ClipboardRepository）をDependency化する。
// テストでは実CoreDataに書き込まないno-op実装を使う（issue #91）。
struct ClipboardRepositoryClient {
    var load: @Sendable () async throws -> [ClipboardItem]
    var save: @Sendable ([ClipboardItem]) async throws -> Void
    var saveAndSync: @Sendable (ClipboardItem) async throws -> Void
    var loadTrash: @Sendable () async throws -> [ClipboardItem]
    var saveTrash: @Sendable ([ClipboardItem]) async throws -> Void
    var deleteItem: @Sendable (ClipboardItem) async throws -> Void
    var clearAll: @Sendable () async throws -> Void
    var emptyTrash: @Sendable () async throws -> Void
}

extension ClipboardRepositoryClient: DependencyKey {
    static let liveValue = ClipboardRepositoryClient(
        load: { try await ClipboardRepository.shared.load() },
        save: { try await ClipboardRepository.shared.save(items: $0) },
        saveAndSync: { try await ClipboardRepository.shared.saveAndSync(item: $0) },
        loadTrash: { try await ClipboardRepository.shared.loadTrash() },
        saveTrash: { try await ClipboardRepository.shared.saveTrash(items: $0) },
        deleteItem: { try await ClipboardRepository.shared.deleteItem($0) },
        clearAll: { try await ClipboardRepository.shared.clearAll() },
        emptyTrash: { try await ClipboardRepository.shared.emptyTrash() }
    )

    static let testValue = ClipboardRepositoryClient(
        load: { [] },
        save: { _ in },
        saveAndSync: { _ in },
        loadTrash: { [] },
        saveTrash: { _ in },
        deleteItem: { _ in },
        clearAll: {},
        emptyTrash: {}
    )
}

extension DependencyValues {
    var clipboardRepository: ClipboardRepositoryClient {
        get { self[ClipboardRepositoryClient.self] }
        set { self[ClipboardRepositoryClient.self] = newValue }
    }
}

// MARK: - SnippetRepositoryClient

// スニペット（定型文）のCoreData I/OをDependency化する（issue #85）。
// テストでは実CoreDataに書き込まないno-op実装を使う。
struct SnippetRepositoryClient {
    var load: @Sendable () async throws -> [Snippet]
    var save: @Sendable ([Snippet]) async throws -> Void
}

extension SnippetRepositoryClient: DependencyKey {
    static let liveValue = SnippetRepositoryClient(
        load: { try await SnippetStorageManager.shared.load() },
        save: { try await SnippetStorageManager.shared.save(snippets: $0) }
    )

    static let testValue = SnippetRepositoryClient(
        load: { [] },
        save: { _ in }
    )
}

extension DependencyValues {
    var snippetRepository: SnippetRepositoryClient {
        get { self[SnippetRepositoryClient.self] }
        set { self[SnippetRepositoryClient.self] = newValue }
    }
}

// MARK: - InterstitialAdClient

// インタースティシャル広告をDependency化する（issue #90）。
// 本体アプリのcopy/paste系actionからのみ配線する（キーボード拡張は本Reducerを
// 使わないため、キーボードからの貼付けでは表示されない）。
// テストでは実AdMob SDKを触らないno-op実装を使う。
struct InterstitialAdClient {
    var loadAd: @Sendable () async -> Void
    var onItemPasted: @Sendable (_ isProUser: Bool) async -> Void
}

extension InterstitialAdClient: DependencyKey {
    static let liveValue = InterstitialAdClient(
        loadAd: {
            await InterstitialAdManager.shared.loadAd()
        },
        onItemPasted: { isProUser in
            await InterstitialAdManager.shared.onItemPasted(isProUser: isProUser)
        }
    )

    static let testValue = InterstitialAdClient(
        loadAd: {},
        onItemPasted: { _ in }
    )
}

extension DependencyValues {
    var interstitialAd: InterstitialAdClient {
        get { self[InterstitialAdClient.self] }
        set { self[InterstitialAdClient.self] = newValue }
    }
}

// MARK: - PendingItemBufferClient

// PiP中の軽量チェックポイント（App Group UserDefaults）をDependency化する。
// テストでは実UserDefaultsに触れないよう空実装を使う。
struct PendingItemBufferClient {
    var load: @Sendable () -> [ClipboardItem]
    var append: @Sendable (ClipboardItem) -> Void
    var clear: @Sendable () -> Void
}

extension PendingItemBufferClient: DependencyKey {
    static let liveValue = PendingItemBufferClient(
        load: { PendingItemBuffer.load() },
        append: { PendingItemBuffer.append($0) },
        clear: { PendingItemBuffer.clear() }
    )

    static let testValue = PendingItemBufferClient(
        load: { [] },
        append: { _ in },
        clear: {}
    )
}

extension DependencyValues {
    var pendingItemBuffer: PendingItemBufferClient {
        get { self[PendingItemBufferClient.self] }
        set { self[PendingItemBufferClient.self] = newValue }
    }
}

// MARK: - RemoteChangeClient

// CloudKit（NSPersistentCloudKitContainer）が他端末の変更を取り込んだことを
// 通知する `.NSPersistentStoreRemoteChange` を購読するためのDependency（issue #102）。
//
// PersistenceController は以前からこの通知を「投げる」設定
// （NSPersistentStoreRemoteChangeNotificationPostOptionKey）にしていたが、
// 購読側が存在しなかったため、他端末で追加されたアイテムがアプリ起動中は
// state.items に反映されなかった。その状態で保存が走ると、state.items に
// 無いアイテムが「削除された」と誤認されて消える事故につながっていた。
struct RemoteChangeClient {
    var changes: @Sendable () -> AsyncStream<Void>
}

extension RemoteChangeClient: DependencyKey {
    static let liveValue = RemoteChangeClient(
        changes: {
            AsyncStream { continuation in
                let task = Task {
                    for await _ in NotificationCenter.default.notifications(
                        named: .NSPersistentStoreRemoteChange
                    ) {
                        continuation.yield(())
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    )

    // テストでは即座に終了するストリームを返す。
    // 終了しないストリームにすると TestStore.finish() が
    // 「エフェクトがまだ実行中」で失敗してしまうため。
    static let testValue = RemoteChangeClient(
        changes: { AsyncStream { $0.finish() } }
    )
}

extension DependencyValues {
    var remoteChange: RemoteChangeClient {
        get { self[RemoteChangeClient.self] }
        set { self[RemoteChangeClient.self] = newValue }
    }
}

// MARK: - SyncStatusClient

// 「最後に他端末の変更を取り込んだ時刻」の記録をDependency化する（issue #103）。
// テストでは実UserDefaultsに触れない。
struct SyncStatusClient {
    var recordSync: @Sendable () -> Void
}

extension SyncStatusClient: DependencyKey {
    static let liveValue = SyncStatusClient(
        recordSync: { CloudKitSyncStatus.lastSyncedAt = Date() }
    )

    static let testValue = SyncStatusClient(
        recordSync: {}
    )
}

extension DependencyValues {
    var syncStatus: SyncStatusClient {
        get { self[SyncStatusClient.self] }
        set { self[SyncStatusClient.self] = newValue }
    }
}
