import Foundation
import ComposableArchitecture
import UIKit
import OSLog
import StoreKit
import FirebaseAnalytics

@Reducer
struct ClipboardHistoryFeature {
    @ObservableState
    struct State: Equatable {
        var items: [ClipboardItem] = []
        let maxItems: Int = Int.max
        var isMonitoring: Bool = false
        var lastChangeCount: Int = UIPasteboard.general.changeCount
        var isAppActive: Bool = true
        var isPiPActive: Bool = false
        var showPermissionAlert: Bool = false
        var hasRequestedPermission: Bool = UserDefaults.standard.bool(forKey: "hasRequestedClipboardPermission")
        var selectedImageItem: ClipboardItem?
        var searchText: String = ""
        var selectedCategory: ItemCategory? = nil
        var showPaywall: Bool = false
        var isProUser: Bool = false
        var trashedItems: [ClipboardItem] = []
        var snippets: [Snippet] = []
        var copyCount: Int = UserDefaults.standard.integer(forKey: "clipkit.copyCount")
        var captureCount: Int = UserDefaults.standard.integer(forKey: "clipkit.captureCount")
        var showSatisfactionPrompt: Bool = false
        var showFeedbackForm: Bool = false

        // 履歴件数制限（無料: 20件、Pro: 無制限）
        var maxHistoryCount: Int {
            return isProUser ? Int.max : 20
        }

        // スニペット件数制限（無料: 3件、Pro: 無制限）
        static let freeSnippetLimit = 3
        var maxSnippetCount: Int {
            return isProUser ? Int.max : Self.freeSnippetLimit
        }
        var canAddSnippet: Bool {
            snippets.count < maxSnippetCount
        }

        // 無料版で表示できる履歴の起点（3日前以降）
        var freeHistoryStartDate: Date {
            Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        }

        // 検索結果のフィルタリング
        var filteredItems: [ClipboardItem] {
            // 無料版は直近3日のみ
            var baseItems = isProUser ? items : items.filter { $0.timestamp >= freeHistoryStartDate }

            // カテゴリフィルター
            if let cat = selectedCategory {
                baseItems = baseItems.filter { $0.category == cat }
            }

            if searchText.isEmpty {
                return baseItems
            }

            return baseItems.filter { item in
                let q = searchText
                switch item.type {
                case .text:
                    return item.textContent?.localizedCaseInsensitiveContains(q) ?? false
                case .url:
                    return item.url?.absoluteString.localizedCaseInsensitiveContains(q) ?? false
                case .file:
                    return item.fileName?.localizedCaseInsensitiveContains(q) ?? false
                case .image:
                    // OCRテキストも検索対象
                    return item.ocrText?.localizedCaseInsensitiveContains(q) ?? false
                }
            }
        }
    }

    enum Action {
        case addItem(ClipboardItem)
        case removeItems(IndexSet)
        case clearAll
        case pasteItem(ClipboardItem)
        case copyItem(ClipboardItem)
        case copyTransformedText(String, TextTransform)
        case toggleFavorite(ClipboardItem)
        case updateSearchText(String)
        case selectCategory(ItemCategory?)
        case updateItemOCR(id: UUID, ocrText: String, category: ItemCategory?)
        case startMonitoring
        case stopMonitoring
        case checkClipboard
        case onAppear
        case appDidBecomeActive
        case appDidEnterBackground
        case requestClipboardPermission
        case dismissPermissionAlert
        case pipStateChanged(Bool)
        case flushPendingPiPItems
        case showImagePreview(ClipboardItem)
        case dismissImagePreview
        case loadItems
        case itemsLoaded([ClipboardItem])
        case saveItems
        case showPaywall
        case dismissPaywall
        case updateProStatus
        case requestReview
        case checkReviewTrigger
        case satisfactionResponsePositive
        case satisfactionResponseNegative
        case dismissSatisfactionPrompt
        case dismissFeedbackForm
        case loadTrash
        case trashLoaded([ClipboardItem])
        case saveTrash
        case restoreItem(ClipboardItem)
        case permanentlyDeleteItem(ClipboardItem)
        case emptyTrash
        case loadSnippets
        case snippetsLoaded([Snippet])
        case saveSnippets
        case addSnippet(title: String, content: String)
        case updateSnippet(Snippet)
        case deleteSnippets(IndexSet)
        case moveSnippets(IndexSet, Int)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.pipClient) var pip
    @Dependency(\.clipboardRepository) var repository
    @Dependency(\.snippetRepository) var snippetRepository
    @Dependency(\.interstitialAd) var interstitialAd
    @Dependency(\.pendingItemBuffer) var pendingBuffer
    private enum CancelID { case monitoring }

    private static let logger = Logger(subsystem: "com.clipkit", category: "Clipboard")

    // 並び替え・削除後にsortOrderをインデックスで振り直す
    private static func renumberSnippets(_ snippets: inout [Snippet]) {
        for index in snippets.indices {
            snippets[index].sortOrder = Int64(index)
        }
    }

    // 画像からClipboardItemを作成（サムネイル付き）
    private static func createImageItem(from image: UIImage) async -> ClipboardItem {
        let thumbnailSize = CGSize(width: 200, height: 200)
        let thumbnail = await image.byPreparingThumbnail(ofSize: thumbnailSize)
        return ClipboardItem(image: image, thumbnail: thumbnail)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .addItem(item):
                state.items.insert(item, at: 0)
                // 履歴件数制限を適用（無料版: 20件、Pro: 無制限）
                let limit = min(state.maxHistoryCount, state.maxItems)
                var overflowItem: ClipboardItem?
                if state.items.count > limit {
                    overflowItem = state.items.removeLast()
                }
                state.captureCount += 1
                UserDefaults.standard.set(state.captureCount, forKey: "clipkit.captureCount")
                let latestItems = Array(state.items.prefix(5))
                let newItem = item
                let pipEffect: Effect<Action> = .run { _ in await pip.updateItems(latestItems) }

                guard !state.isPiPActive else {
                    // PiP中はCoreData書き込み（CloudKit同期のトリガー）を避け、
                    // 軽量なローカルチェックポイントのみ即時に行う。
                    // あふれたアイテムの削除も次回の.saveItems（差分ベース保存）で
                    // 自然にプルーニングされるため、ここでは明示的に削除しない。
                    // 本保存はPiP終了時（.flushPendingPiPItems）にまとめて行う。
                    pendingBuffer.append(newItem)
                    return .merge(.send(.checkReviewTrigger), pipEffect)
                }

                let deleteOverflowEffect: Effect<Action> = overflowItem.map { removed in
                    .run { _ in
                        do {
                            try await repository.deleteItem(removed)
                        } catch {
                            Self.logger.error("Failed to delete overflow item: \(error.localizedDescription)")
                        }
                    }
                } ?? .none

                return .merge(
                    .send(.saveItems),
                    .send(.checkReviewTrigger),
                    .run { _ in
                        do {
                            try await repository.saveAndSync(newItem)
                        } catch {
                            Self.logger.error("Failed to saveAndSync item: \(error.localizedDescription)")
                        }
                    },
                    deleteOverflowEffect,
                    pipEffect
                )

            case let .removeItems(indexSet):
                if state.isProUser {
                    // Proユーザー: ゴミ箱へ移動
                    for index in indexSet {
                        if index < state.items.count {
                            var trashed = state.items[index]
                            trashed.deletedAt = Date()
                            state.trashedItems.insert(trashed, at: 0)
                        }
                    }
                    state.items.remove(atOffsets: indexSet)
                    let afterRemove = Array(state.items.prefix(5))
                    return .merge(
                        .send(.saveItems), .send(.saveTrash),
                        .run { _ in await pip.updateItems(afterRemove) }
                    )
                } else {
                    let toDelete = indexSet.compactMap { $0 < state.items.count ? state.items[$0] : nil }
                    state.items.remove(atOffsets: indexSet)
                    let afterRemove = Array(state.items.prefix(5))
                    return .merge(
                        .send(.saveItems),
                        .run { _ in await pip.updateItems(afterRemove) },
                        .run { _ in
                            for item in toDelete {
                                do {
                                    try await repository.deleteItem(item)
                                } catch {
                                    Self.logger.error("Failed to delete item: \(error.localizedDescription)")
                                }
                            }
                        }
                    )
                }

            case .clearAll:
                if state.isProUser {
                    // Proユーザー: すべてゴミ箱へ移動
                    let now = Date()
                    let newTrashed = state.items.map { item -> ClipboardItem in
                        var t = item; t.deletedAt = now; return t
                    }
                    state.trashedItems.insert(contentsOf: newTrashed, at: 0)
                    state.items.removeAll()
                    return .merge(
                        .send(.saveItems), .send(.saveTrash),
                        .run { _ in await pip.updateItems([]) }
                    )
                } else {
                    state.items.removeAll()
                    return .merge(
                        .send(.saveItems),
                        .run { _ in await pip.updateItems([]) },
                        .run { _ in
                            do {
                                try await repository.clearAll()
                            } catch {
                                Self.logger.error("Failed to clear all items: \(error.localizedDescription)")
                            }
                        }
                    )
                }
                
            case let .copyItem(item):
                // クリップボードにセットし、履歴の先頭に移動
                switch item.type {
                case .text:
                    UIPasteboard.general.string = item.textContent
                case .url:
                    UIPasteboard.general.url = item.url
                case .image:
                    if let image = item.thumbnail {
                        UIPasteboard.general.image = image
                    }
                case .file:
                    break
                }
                state.lastChangeCount = UIPasteboard.general.changeCount
                // 履歴の先頭に移動（タイムスタンプ更新）
                if let index = state.items.firstIndex(where: { $0.id == item.id }) {
                    var updated = state.items[index]
                    updated.timestamp = Date()
                    state.items.remove(at: index)
                    state.items.insert(updated, at: 0)
                }
                state.copyCount += 1
                UserDefaults.standard.set(state.copyCount, forKey: "clipkit.copyCount")
                Analytics.logEvent("copy_item", parameters: ["item_type": item.type.rawValue])
                let afterCopy = Array(state.items.prefix(5))
                let isProUser = state.isProUser
                let pipEffect: Effect<Action> = .run { _ in await pip.updateItems(afterCopy) }
                return .merge(
                    .send(.saveItems),
                    pipEffect,
                    .run { _ in await interstitialAd.onItemPasted(isProUser) }
                )

            case let .copyTransformedText(text, transform):
                // 変換後テキストをクリップボードへ。lastChangeCount は更新せず、
                // 監視ループに新規履歴アイテムとして取り込ませる
                UIPasteboard.general.string = text
                state.copyCount += 1
                UserDefaults.standard.set(state.copyCount, forKey: "clipkit.copyCount")
                Analytics.logEvent("transform_copy", parameters: ["transform": transform.rawValue])
                let isProUser = state.isProUser
                return .run { _ in await interstitialAd.onItemPasted(isProUser) }

            case let .pasteItem(item):
                switch item.type {
                case .text:
                    UIPasteboard.general.string = item.textContent
                case .url:
                    UIPasteboard.general.url = item.url
                case .image:
                    if let image = item.thumbnail {
                        UIPasteboard.general.image = image
                    }
                case .file:
                    break
                }
                let isProUser = state.isProUser
                return .run { _ in await interstitialAd.onItemPasted(isProUser) }

            case let .toggleFavorite(item):
                // 無料ユーザーはお気に入り10件まで
                if !state.isProUser {
                    let currentFavoriteCount = state.items.filter { $0.isFavorite }.count
                    let isCurrentlyFavorite = state.items.first(where: { $0.id == item.id })?.isFavorite ?? false
                    // 解除は常に可能。追加は10件未満のときのみ
                    if !isCurrentlyFavorite && currentFavoriteCount >= 10 {
                        return .send(.showPaywall)
                    }
                }

                if let index = state.items.firstIndex(where: { $0.id == item.id }) {
                    let newValue = !state.items[index].isFavorite
                    Analytics.logEvent("toggle_favorite", parameters: ["is_favorite": newValue])
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
                    let afterToggle = Array(state.items.prefix(5))
                    return .merge(
                        .send(.saveItems),
                        .run { _ in await pip.updateItems(afterToggle) }
                    )
                }
                return .none

            case let .updateSearchText(text):
                state.searchText = text
                return .none

            case let .selectCategory(category):
                state.selectedCategory = category
                return .none

            case let .updateItemOCR(id, ocrText, category):
                if let index = state.items.firstIndex(where: { $0.id == id }) {
                    state.items[index].ocrText = ocrText
                    if let cat = category {
                        state.items[index].category = cat
                    }
                }
                // PiP中はCoreData書き込みを避ける（.flushPendingPiPItemsで後からまとめて保存される）
                guard !state.isPiPActive else { return .none }
                return .send(.saveItems)

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
                return .merge(
                    .cancel(id: CancelID.monitoring),
                    .run { _ in await pip.stopPiP() }
                )
                
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
                    // 直前の画像と同じサイズなら重複とみなしてスキップ
                    if let lastItem = state.items.first,
                       lastItem.type == .image,
                       let lastThumb = lastItem.thumbnail,
                       lastThumb.size == image.size {
                        Self.logger.debug("Skipping duplicate image")
                        return .none
                    }
                    let isPiPActive = state.isPiPActive
                    return .run { send in
                        var item = await Self.createImageItem(from: image)
                        await send(.addItem(item))
                        // PiP中はVisionによる重いOCR処理を避ける。背景実行のタイムアウトで
                        // プロセスごと強制終了されるのを防ぐため（OCR検索は次回起動時に取りこぼす）。
                        guard !isPiPActive else { return }
                        // OCRをバックグラウンドで実行してアイテムを更新
                        if let text = await ClipboardItemAnalyzer.extractText(from: image), !text.isEmpty {
                            let cat = ClipboardItemAnalyzer.category(for: text)
                            await send(.updateItemOCR(id: item.id, ocrText: text, category: cat))
                        }
                    }
                }

                // URLをチェック
                if let url = UIPasteboard.general.url {
                    Self.logger.info("Got URL: \(url.absoluteString)")
                    if let lastItem = state.items.first,
                       lastItem.type == .url,
                       lastItem.url == url {
                        Self.logger.debug("Skipping duplicate URL")
                        return .none
                    }
                    var item = ClipboardItem(url: url)
                    item.category = .url
                    return .send(.addItem(item))
                }

                // テキストをチェック
                if let content = UIPasteboard.general.string {
                    let preview = String(content.prefix(50))
                    Self.logger.info("Got text content: \(preview)...")
                    if let lastItem = state.items.first,
                       lastItem.type == .text,
                       lastItem.textContent == content {
                        Self.logger.debug("Skipping duplicate text")
                        return .none
                    }
                    var item = ClipboardItem(content: content)
                    item.category = ClipboardItemAnalyzer.category(for: content)
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
                return .send(.flushPendingPiPItems)
                
            case .appDidEnterBackground:
                state.isAppActive = false
                return .none
                
            case .onAppear:
                return .merge(
                    .send(.updateProStatus),
                    .send(.loadItems),
                    .send(.loadTrash),
                    .send(.loadSnippets),
                    .send(.checkReviewTrigger)
                )

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
                guard !isActive else { return .none }
                return .send(.flushPendingPiPItems)

            case .flushPendingPiPItems:
                let pending = pendingBuffer.load()
                guard !pending.isEmpty else { return .none }

                let existingIDs = Set(state.items.map(\.id))
                let newOnes = pending.filter { !existingIDs.contains($0.id) }
                if !newOnes.isEmpty {
                    state.items.insert(contentsOf: newOnes, at: 0)
                    state.items.sort { lhs, rhs in
                        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
                        return lhs.timestamp > rhs.timestamp
                    }
                    let limit = min(state.maxHistoryCount, state.maxItems)
                    if state.items.count > limit {
                        state.items.removeLast(state.items.count - limit)
                    }
                }
                pendingBuffer.clear()

                let latestItems = Array(state.items.prefix(5))
                return .merge(
                    .send(.saveItems),
                    .run { _ in await pip.updateItems(latestItems) }
                )

            case let .showImagePreview(item):
                state.selectedImageItem = item
                return .none

            case .dismissImagePreview:
                state.selectedImageItem = nil
                return .none

            case .loadItems:
                return .run { send in
                    do {
                        let items = try await repository.load()
                        await send(.itemsLoaded(items))
                    } catch {
                        Self.logger.error("Failed to load items: \(error.localizedDescription)")
                        await send(.itemsLoaded([]))
                    }
                }


            case let .itemsLoaded(items):
                state.items = items.sorted { lhs, rhs in
                    if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
                    return lhs.timestamp > rhs.timestamp
                }
                Self.logger.info("Loaded \(items.count) items from storage")

                if !state.hasRequestedPermission {
                    state.showPermissionAlert = true
                }

                let latestItems = Array(state.items.prefix(5))
                return .merge(
                    .run { _ in await pip.updateItems(latestItems) },
                    // 前回起動時にPiP中で本保存できず退避されたアイテムがあれば復旧する
                    .send(.flushPendingPiPItems)
                )

            case .saveItems:
                let items = state.items
                return .run { _ in
                    do {
                        try await repository.save(items)
                    } catch {
                        Self.logger.error("Failed to save items: \(error.localizedDescription)")
                    }
                }

            case .showPaywall:
                Analytics.logEvent("show_paywall", parameters: nil)
                state.showPaywall = true
                return .none

            case .dismissPaywall:
                state.showPaywall = false
                // Paywallを閉じた後、Pro状態を更新
                return .send(.updateProStatus)

            case .updateProStatus:
                let newProStatus = RevenueCatManager.shared.hasProAccess()
                let becamePro = !state.isProUser && newProStatus
                state.isProUser = newProStatus
                Self.logger.info("Pro status updated: \(newProStatus)")
                var effects: [Effect<Action>] = []
                if becamePro {
                    effects.append(.send(.requestReview))
                }
                if !newProStatus {
                    // 無料ユーザーのみインタースティシャル広告をプリロード
                    // （ロード済みならInterstitialAdManager側でスキップされる）
                    effects.append(.run { _ in await interstitialAd.loadAd() })
                }
                return .merge(effects)

            case .loadTrash:
                return .run { send in
                    do {
                        let items = try await repository.loadTrash()
                        // 30日以上経過したアイテムを除外
                        let threshold = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                        let valid = items.filter { ($0.deletedAt ?? Date()) >= threshold }
                        await send(.trashLoaded(valid))
                    } catch {
                        Self.logger.error("Failed to load trash: \(error.localizedDescription)")
                        await send(.trashLoaded([]))
                    }
                }

            case let .trashLoaded(items):
                state.trashedItems = items.sorted { ($0.deletedAt ?? Date()) > ($1.deletedAt ?? Date()) }
                return .none

            case .saveTrash:
                let items = state.trashedItems
                return .run { _ in
                    do {
                        try await repository.saveTrash(items)
                    } catch {
                        Self.logger.error("Failed to save trash: \(error.localizedDescription)")
                    }
                }

            case let .restoreItem(item):
                if let index = state.trashedItems.firstIndex(where: { $0.id == item.id }) {
                    var restored = state.trashedItems[index]
                    restored.deletedAt = nil
                    restored.timestamp = Date()
                    state.trashedItems.remove(at: index)
                    state.items.insert(restored, at: 0)
                }
                let afterRestore = Array(state.items.prefix(5))
                return .merge(
                    .send(.saveItems), .send(.saveTrash),
                    .run { _ in await pip.updateItems(afterRestore) }
                )

            case let .permanentlyDeleteItem(item):
                state.trashedItems.removeAll { $0.id == item.id }
                return .merge(
                    .send(.saveTrash),
                    .run { _ in
                        do {
                            try await repository.deleteItem(item)
                        } catch {
                            Self.logger.error("Failed to permanently delete item: \(error.localizedDescription)")
                        }
                    }
                )

            case .requestReview:
                return .run { _ in
                    await MainActor.run {
                        guard let scene = UIApplication.shared.connectedScenes
                            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
                        AppStore.requestReview(in: scene)
                    }
                }

            case .checkReviewTrigger:
                let defaults = UserDefaults.standard
                let shown = defaults.stringArray(forKey: "clipkit.reviewMilestonesShown") ?? []
                let count = state.captureCount
                // クリップボード保存回数のマイルストーンで満足度プロンプトを表示
                // 5回: アプリを試し始めたタイミング
                // 20回: 継続的に利用しているタイミング
                // 50回: ヘビーユーザーのタイミング
                if count >= 50 && !shown.contains("capture50") {
                    defaults.set(shown + ["capture50"], forKey: "clipkit.reviewMilestonesShown")
                    state.showSatisfactionPrompt = true
                } else if count >= 20 && !shown.contains("capture20") {
                    defaults.set(shown + ["capture20"], forKey: "clipkit.reviewMilestonesShown")
                    state.showSatisfactionPrompt = true
                } else if count >= 5 && !shown.contains("capture5") {
                    defaults.set(shown + ["capture5"], forKey: "clipkit.reviewMilestonesShown")
                    state.showSatisfactionPrompt = true
                }
                return .none

            case .satisfactionResponsePositive:
                return .send(.requestReview)

            case .satisfactionResponseNegative:
                state.showFeedbackForm = true
                return .none

            case .dismissSatisfactionPrompt:
                state.showSatisfactionPrompt = false
                return .none

            case .dismissFeedbackForm:
                state.showFeedbackForm = false
                return .none

            case .emptyTrash:
                state.trashedItems.removeAll()
                return .merge(
                    .send(.saveTrash),
                    // 個別削除（N+1）ではなく単一トランザクションのバッチ削除を使う
                    .run { _ in
                        do {
                            try await repository.emptyTrash()
                        } catch {
                            Self.logger.error("Failed to empty trash: \(error.localizedDescription)")
                        }
                    }
                )

            // MARK: - Snippets（定型文, issue #85）

            case .loadSnippets:
                return .run { send in
                    do {
                        let snippets = try await snippetRepository.load()
                        await send(.snippetsLoaded(snippets))
                    } catch {
                        Self.logger.error("Failed to load snippets: \(error.localizedDescription)")
                        await send(.snippetsLoaded([]))
                    }
                }

            case let .snippetsLoaded(snippets):
                state.snippets = snippets.sorted { $0.sortOrder < $1.sortOrder }
                return .none

            case .saveSnippets:
                let snippets = state.snippets
                return .run { _ in
                    do {
                        try await snippetRepository.save(snippets)
                    } catch {
                        Self.logger.error("Failed to save snippets: \(error.localizedDescription)")
                    }
                }

            case let .addSnippet(title, content):
                // 無料ユーザーは3件まで
                guard state.canAddSnippet else {
                    return .send(.showPaywall)
                }
                let snippet = Snippet(
                    title: title,
                    content: content,
                    sortOrder: Int64(state.snippets.count)
                )
                state.snippets.append(snippet)
                Analytics.logEvent("add_snippet", parameters: nil)
                return .send(.saveSnippets)

            case let .updateSnippet(snippet):
                guard let index = state.snippets.firstIndex(where: { $0.id == snippet.id }) else {
                    return .none
                }
                var updated = snippet
                updated.updatedAt = Date()
                state.snippets[index] = updated
                return .send(.saveSnippets)

            case let .deleteSnippets(indexSet):
                state.snippets.remove(atOffsets: indexSet)
                Self.renumberSnippets(&state.snippets)
                return .send(.saveSnippets)

            case let .moveSnippets(source, destination):
                state.snippets.move(fromOffsets: source, toOffset: destination)
                Self.renumberSnippets(&state.snippets)
                return .send(.saveSnippets)
            }
        }
    }
} 