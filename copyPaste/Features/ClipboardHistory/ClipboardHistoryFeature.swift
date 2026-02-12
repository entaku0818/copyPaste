import Foundation
import ComposableArchitecture
import UIKit
import OSLog

@Reducer
struct ClipboardHistoryFeature {
    @ObservableState
    struct State: Equatable {
        var items: [ClipboardItem] = []
        let maxItems: Int = 100
        var isMonitoring: Bool = false
        var lastChangeCount: Int = UIPasteboard.general.changeCount
        var isAppActive: Bool = true
        var isPiPActive: Bool = false
        var showPermissionAlert: Bool = false
        var hasRequestedPermission: Bool = UserDefaults.standard.bool(forKey: "hasRequestedClipboardPermission")
        var selectedImageItem: ClipboardItem?
        var searchText: String = ""

        // 検索結果のフィルタリング
        var filteredItems: [ClipboardItem] {
            if searchText.isEmpty {
                return items
            }

            return items.filter { item in
                switch item.type {
                case .text:
                    return item.textContent?.localizedCaseInsensitiveContains(searchText) ?? false
                case .url:
                    return item.url?.absoluteString.localizedCaseInsensitiveContains(searchText) ?? false
                case .file:
                    return item.fileName?.localizedCaseInsensitiveContains(searchText) ?? false
                case .image:
                    // 画像は検索対象外（または将来的にOCRで対応）
                    return false
                }
            }
        }
    }

    enum Action {
        case addItem(ClipboardItem)
        case removeItems(IndexSet)
        case clearAll
        case pasteItem(ClipboardItem)
        case toggleFavorite(ClipboardItem)
        case updateSearchText(String)
        case startMonitoring
        case stopMonitoring
        case checkClipboard
        case onAppear
        case appDidBecomeActive
        case appDidEnterBackground
        case requestClipboardPermission
        case dismissPermissionAlert
        case pipStateChanged(Bool)
        case showImagePreview(ClipboardItem)
        case dismissImagePreview
        case loadItems
        case itemsLoaded([ClipboardItem])
        case saveItems
    }

    @Dependency(\.continuousClock) var clock
    private enum CancelID { case monitoring }

    private static let logger = Logger(subsystem: "com.copyPaste", category: "Clipboard")

    // 画像からClipboardItemを作成（サムネイル付き）
    private static func createImageItem(from image: UIImage) async -> ClipboardItem {
        // サムネイル生成（200x200）
        let thumbnailSize = CGSize(width: 200, height: 200)
        let thumbnail = await image.byPreparingThumbnail(ofSize: thumbnailSize)

        return ClipboardItem(
            image: image,
            thumbnail: thumbnail
        )
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .addItem(item):
                state.items.insert(item, at: 0)
                if state.items.count > state.maxItems {
                    let removed = state.items.removeLast()
                    // 削除されたアイテムのファイルも削除
                    try? ClipboardStorageManager.shared.deleteItem(removed)
                }
                return .send(.saveItems)

            case let .removeItems(indexSet):
                // 削除されるアイテムのファイルも削除
                for index in indexSet {
                    if index < state.items.count {
                        try? ClipboardStorageManager.shared.deleteItem(state.items[index])
                    }
                }
                state.items.remove(atOffsets: indexSet)
                return .send(.saveItems)

            case .clearAll:
                // すべてのファイルを削除
                try? ClipboardStorageManager.shared.clearAll()
                state.items.removeAll()
                return .send(.saveItems)
                
            case .pasteItem:
                // Paste functionality will be implemented later
                return .none

            case let .toggleFavorite(item):
                if let index = state.items.firstIndex(where: { $0.id == item.id }) {
                    state.items[index].isFavorite.toggle()
                    // お気に入りの状態が変わったらソート
                    state.items.sort { lhs, rhs in
                        // お気に入りを先頭に
                        if lhs.isFavorite != rhs.isFavorite {
                            return lhs.isFavorite
                        }
                        // 同じお気に入り状態なら日時でソート
                        return lhs.timestamp > rhs.timestamp
                    }
                    return .send(.saveItems)
                }
                return .none

            case let .updateSearchText(text):
                state.searchText = text
                return .none

            case .startMonitoring:
                guard !state.isMonitoring else {
                    Self.logger.warning("Already monitoring")
                    return .none
                }
                Self.logger.info("Starting clipboard monitoring...")
                state.isMonitoring = true
                // PiPは手動で起動する
                // PiPManager.shared.startPiP()

                return .run { send in
                    await withTaskGroup(of: Void.self) { group in
                        // アプリの状態変化を監視
                        group.addTask {
                            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                                await send(.appDidBecomeActive)
                            }
                        }

                        group.addTask {
                            for await _ in NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification) {
                                await send(.appDidEnterBackground)
                            }
                        }

                        // 1秒ごとにクリップボードをチェック
                        group.addTask {
                            for await _ in clock.timer(interval: .seconds(1)) {
                                await send(.checkClipboard)
                            }
                        }
                    }
                }
                .cancellable(id: CancelID.monitoring)
                
            case .stopMonitoring:
                guard state.isMonitoring else { return .none }
                state.isMonitoring = false
                PiPManager.shared.stopPiP()
                return .cancel(id: CancelID.monitoring)
                
            case .checkClipboard:
                // PiPモード中はバックグラウンドでもチェックを試みる
                // 通常モードではアプリがアクティブな時のみチェック
                guard state.isAppActive || state.isPiPActive else {
                    Self.logger.debug("Skipping clipboard check - app not active and PiP not active")
                    return .none
                }

                let currentChangeCount = UIPasteboard.general.changeCount
                let lastChangeCount = state.lastChangeCount
                guard currentChangeCount != lastChangeCount else {
                    return .none
                }

                Self.logger.info("Change detected! Count: \(currentChangeCount) (was: \(lastChangeCount))")
                state.lastChangeCount = currentChangeCount

                // 画像をチェック（優先度：高）
                if let image = UIPasteboard.general.image {
                    Self.logger.info("Got image from clipboard")
                    return .run { send in
                        let item = await Self.createImageItem(from: image)
                        await send(.addItem(item))
                    }
                }

                // URLをチェック
                if let url = UIPasteboard.general.url {
                    Self.logger.info("Got URL: \(url.absoluteString)")
                    let item = ClipboardItem(url: url)
                    return .send(.addItem(item))
                }

                // テキストをチェック
                if let content = UIPasteboard.general.string {
                    let preview = String(content.prefix(50))
                    Self.logger.info("Got text content: \(preview)...")
                    let item = ClipboardItem(content: content)
                    return .send(.addItem(item))
                }

                // iOS 16+: hasStringsでアクセス可否を確認
                if UIPasteboard.general.hasStrings {
                    Self.logger.warning("Clipboard has strings but access denied")
                } else {
                    Self.logger.debug("No content in clipboard")
                }

                return .none
                
            case .appDidBecomeActive:
                state.isAppActive = true
                return .none
                
            case .appDidEnterBackground:
                state.isAppActive = false
                return .none
                
            case .onAppear:
                // 保存されたアイテムを読み込む
                return .send(.loadItems)

            case .requestClipboardPermission:
                state.showPermissionAlert = false
                state.hasRequestedPermission = true
                UserDefaults.standard.set(true, forKey: "hasRequestedClipboardPermission")

                // クリップボードアクセスを試みて、システムの確認ダイアログを表示
                if let content = UIPasteboard.general.string {
                    let item = ClipboardItem(content: content)
                    return .send(.addItem(item))
                }
                return .none

            case .dismissPermissionAlert:
                state.showPermissionAlert = false
                return .none

            case let .pipStateChanged(isActive):
                Self.logger.info("PiP state changed: \(isActive)")
                state.isPiPActive = isActive
                return .none

            case let .showImagePreview(item):
                state.selectedImageItem = item
                return .none

            case .dismissImagePreview:
                state.selectedImageItem = nil
                return .none

            case .loadItems:
                return .run { send in
                    do {
                        let items = try await ClipboardStorageManager.shared.load()
                        await send(.itemsLoaded(items))
                    } catch {
                        Self.logger.error("Failed to load items: \(error.localizedDescription)")
                        await send(.itemsLoaded([]))
                    }
                }

            case let .itemsLoaded(items):
                // お気に入りを先頭に、その後は日時順にソート
                state.items = items.sorted { lhs, rhs in
                    if lhs.isFavorite != rhs.isFavorite {
                        return lhs.isFavorite
                    }
                    return lhs.timestamp > rhs.timestamp
                }
                Self.logger.info("Loaded \(items.count) items from storage")

                // 初回起動時にクリップボードアクセスの説明を表示
                if !state.hasRequestedPermission {
                    state.showPermissionAlert = true
                }

                return .none

            case .saveItems:
                let items = state.items
                return .run { _ in
                    do {
                        try await ClipboardStorageManager.shared.save(items: items)
                    } catch {
                        Self.logger.error("Failed to save items: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
} 