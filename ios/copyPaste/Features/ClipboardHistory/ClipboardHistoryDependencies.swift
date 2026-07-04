import Foundation
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
    var deleteItem: @Sendable (ClipboardItem) throws -> Void
    var clearAll: @Sendable () throws -> Void
    var emptyTrash: @Sendable () throws -> Void
}

extension ClipboardRepositoryClient: DependencyKey {
    static let liveValue = ClipboardRepositoryClient(
        load: { try await ClipboardRepository.shared.load() },
        save: { try await ClipboardRepository.shared.save(items: $0) },
        saveAndSync: { try await ClipboardRepository.shared.saveAndSync(item: $0) },
        loadTrash: { try await ClipboardRepository.shared.loadTrash() },
        saveTrash: { try await ClipboardRepository.shared.saveTrash(items: $0) },
        deleteItem: { try ClipboardRepository.shared.deleteItem($0) },
        clearAll: { try ClipboardRepository.shared.clearAll() },
        emptyTrash: { try ClipboardRepository.shared.emptyTrash() }
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
