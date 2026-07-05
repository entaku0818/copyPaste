import XCTest
import ComposableArchitecture
@testable import ClipKit

@MainActor
final class ClipboardHistoryFeatureTests: XCTestCase {

    // MARK: - Favorite Functionality Tests (Pro user)

    func testToggleFavorite_makesItemFavorite() async {
        let item = ClipboardItem(content: "Test", isFavorite: false)

        let store = TestStore(initialState: ClipboardHistoryFeature.State(items: [item], isProUser: true)) {
            ClipboardHistoryFeature()
        }

        await store.send(.toggleFavorite(item)) {
            $0.items[0].isFavorite = true
        }

        await store.receive(\.saveItems)
        await store.finish()
    }

    func testToggleFavorite_unfavoritesItem() async {
        let item = ClipboardItem(content: "Test", isFavorite: true)

        let store = TestStore(initialState: ClipboardHistoryFeature.State(items: [item], isProUser: true)) {
            ClipboardHistoryFeature()
        }

        await store.send(.toggleFavorite(item)) {
            $0.items[0].isFavorite = false
        }

        await store.receive(\.saveItems)
        await store.finish()
    }

    func testToggleFavorite_sortsItemsCorrectly() async {
        let item1 = ClipboardItem(
            id: UUID(),
            content: "First",
            timestamp: Date(timeIntervalSince1970: 100),
            isFavorite: false
        )
        let item2 = ClipboardItem(
            id: UUID(),
            content: "Second",
            timestamp: Date(timeIntervalSince1970: 200),
            isFavorite: false
        )

        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item2, item1], isProUser: true)
        ) {
            ClipboardHistoryFeature()
        }

        await store.send(.toggleFavorite(item1)) {
            $0.items = [
                ClipboardItem(
                    id: item1.id,
                    content: "First",
                    timestamp: Date(timeIntervalSince1970: 100),
                    isFavorite: true
                ),
                item2
            ]
        }

        await store.receive(\.saveItems)
        await store.finish()
    }

    func testToggleFavorite_maintainsSortingWithMultipleFavorites() async {
        let item1 = ClipboardItem(
            id: UUID(),
            content: "First",
            timestamp: Date(timeIntervalSince1970: 100),
            isFavorite: true
        )
        let item2 = ClipboardItem(
            id: UUID(),
            content: "Second",
            timestamp: Date(timeIntervalSince1970: 200),
            isFavorite: false
        )
        let item3 = ClipboardItem(
            id: UUID(),
            content: "Third",
            timestamp: Date(timeIntervalSince1970: 300),
            isFavorite: true
        )

        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item3, item1, item2], isProUser: true)
        ) {
            ClipboardHistoryFeature()
        }

        await store.send(.toggleFavorite(item2)) {
            $0.items = [
                item3,
                ClipboardItem(
                    id: item2.id,
                    content: "Second",
                    timestamp: Date(timeIntervalSince1970: 200),
                    isFavorite: true
                ),
                item1
            ]
        }

        await store.receive(\.saveItems)
        await store.finish()
    }

    func testItemsLoaded_sortsFavoritesFirst() async {
        let item1 = ClipboardItem(
            id: UUID(),
            content: "Regular",
            timestamp: Date(timeIntervalSince1970: 300),
            isFavorite: false
        )
        let item2 = ClipboardItem(
            id: UUID(),
            content: "Favorite",
            timestamp: Date(timeIntervalSince1970: 100),
            isFavorite: true
        )
        let item3 = ClipboardItem(
            id: UUID(),
            content: "Another Regular",
            timestamp: Date(timeIntervalSince1970: 200),
            isFavorite: false
        )

        var initialState = ClipboardHistoryFeature.State()
        initialState.hasRequestedPermission = true

        let store = TestStore(initialState: initialState) {
            ClipboardHistoryFeature()
        }

        await store.send(.itemsLoaded([item1, item2, item3])) {
            $0.items = [item2, item1, item3]
        }
        await store.receive(\.flushPendingPiPItems)
        await store.finish()
    }

    // MARK: - Free user paywall tests

    func testToggleFavorite_freeUser_showsPaywall() async {
        // フリーユーザーは10件まで追加可能、11件目でPaywall表示
        let favorites = (0..<10).map { ClipboardItem(content: "Favorite \($0)", isFavorite: true) }
        let newItem = ClipboardItem(content: "New Item", isFavorite: false)
        let allItems = favorites + [newItem]

        let store = TestStore(initialState: ClipboardHistoryFeature.State(items: allItems, isProUser: false)) {
            ClipboardHistoryFeature()
        }

        await store.send(.toggleFavorite(newItem))
        await store.receive(\.showPaywall) {
            $0.showPaywall = true
        }
    }

    func testToggleFavorite_nonExistentItem_doesNothing() async {
        let item1 = ClipboardItem(content: "Test")
        let item2 = ClipboardItem(content: "Other")

        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item1], isProUser: true)
        ) {
            ClipboardHistoryFeature()
        }

        await store.send(.toggleFavorite(item2))
    }

    // MARK: - Search Functionality Tests (Pro user)

    func testUpdateSearchText() async {
        let store = TestStore(initialState: ClipboardHistoryFeature.State(isProUser: true)) {
            ClipboardHistoryFeature()
        }

        await store.send(.updateSearchText("test")) {
            $0.searchText = "test"
        }
    }

    func testFilteredItems_emptySearch_returnsAllItems() {
        let item1 = ClipboardItem(content: "Hello")
        let item2 = ClipboardItem(content: "World")

        var state = ClipboardHistoryFeature.State(items: [item1, item2], isProUser: true)
        state.searchText = ""

        XCTAssertEqual(state.filteredItems.count, 2)
    }

    func testFilteredItems_textSearch() {
        let item1 = ClipboardItem(content: "Hello World")
        let item2 = ClipboardItem(content: "Goodbye Moon")
        let item3 = ClipboardItem(content: "Hello Moon")

        var state = ClipboardHistoryFeature.State(items: [item1, item2, item3], isProUser: true)
        state.searchText = "hello"

        XCTAssertEqual(state.filteredItems.count, 2)
        XCTAssertTrue(state.filteredItems.contains(where: { $0.id == item1.id }))
        XCTAssertTrue(state.filteredItems.contains(where: { $0.id == item3.id }))
    }

    func testFilteredItems_urlSearch() {
        let item1 = ClipboardItem(url: URL(string: "https://www.apple.com")!)
        let item2 = ClipboardItem(url: URL(string: "https://www.google.com")!)
        let item3 = ClipboardItem(content: "apple juice")

        var state = ClipboardHistoryFeature.State(items: [item1, item2, item3], isProUser: true)
        state.searchText = "apple"

        XCTAssertEqual(state.filteredItems.count, 2)
        XCTAssertTrue(state.filteredItems.contains(where: { $0.id == item1.id }))
        XCTAssertTrue(state.filteredItems.contains(where: { $0.id == item3.id }))
    }

    func testFilteredItems_caseInsensitive() {
        let item1 = ClipboardItem(content: "HELLO WORLD")
        let item2 = ClipboardItem(content: "goodbye")

        var state = ClipboardHistoryFeature.State(items: [item1, item2], isProUser: true)
        state.searchText = "hello"

        XCTAssertEqual(state.filteredItems.count, 1)
        XCTAssertEqual(state.filteredItems.first?.id, item1.id)
    }

    func testFilteredItems_noMatch() {
        let item1 = ClipboardItem(content: "Hello")
        let item2 = ClipboardItem(content: "World")

        var state = ClipboardHistoryFeature.State(items: [item1, item2], isProUser: true)
        state.searchText = "xyz"

        XCTAssertEqual(state.filteredItems.count, 0)
    }

    func testFilteredItems_partialMatch() {
        let item1 = ClipboardItem(content: "Hello World")
        let item2 = ClipboardItem(content: "World Hello")
        let item3 = ClipboardItem(content: "Goodbye")

        var state = ClipboardHistoryFeature.State(items: [item1, item2, item3], isProUser: true)
        state.searchText = "wor"

        XCTAssertEqual(state.filteredItems.count, 2)
    }

    // MARK: - Free user date filter tests

    func testFilteredItems_freeUser_onlyShowsRecentItems() {
        let recentItem = ClipboardItem(content: "Recent", timestamp: Date())
        let oldItem = ClipboardItem(
            content: "Old",
            timestamp: Date(timeIntervalSinceNow: -4 * 24 * 60 * 60) // 4日前
        )

        var state = ClipboardHistoryFeature.State(items: [recentItem, oldItem], isProUser: false)
        state.searchText = ""

        XCTAssertEqual(state.filteredItems.count, 1)
        XCTAssertEqual(state.filteredItems.first?.id, recentItem.id)
    }

    // MARK: - Regression Tests: お気に入りUI反映バグ（stale値コピー問題）
    //
    // 【バグの原因】
    // .sheet(item:) の content クロージャに値型コピーを渡していたため、
    // toggleFavorite 後もシート内の item.isFavorite が古い値のままだった。
    // ユーザーが「反映されない」と思い二度押しし、false に戻るケースが発生。
    //
    // 【修正】
    // store.items.first(where: { $0.id == sheetItem.id }) で最新を引き直す。

    /// 観点1: toggleFavorite 後、IDで引いた isFavorite が正しく反転していること
    func testToggleFavorite_isFavoriteReflectedByIDLookup() async {
        let item = ClipboardItem(content: "Test", isFavorite: false)
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item], isProUser: true)
        ) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        // false → true
        await store.send(.toggleFavorite(item)) {
            $0.items[0].isFavorite = true
        }

        XCTAssertTrue(
            store.state.items.first(where: { $0.id == item.id })!.isFavorite,
            "toggleFavorite後、IDで引いた値がtrueになっていること"
        )

        // true → false（二度押しで元に戻る）
        await store.send(.toggleFavorite(store.state.items[0])) {
            $0.items[0].isFavorite = false
        }

        XCTAssertFalse(
            store.state.items.first(where: { $0.id == item.id })!.isFavorite,
            "再toggleFavorite後、IDで引いた値がfalseに戻ること"
        )
        await store.finish()
    }

    /// 観点2a（リグレッション）: 修正前のバグパターンを文書化
    /// 値型コピーは toggleFavorite 後も古い値のまま ＝ これが UI 不反映の原因だった
    func testToggleFavorite_staleValueCopyRemainsUnchanged() async {
        let item = ClipboardItem(content: "Test", isFavorite: false)
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item], isProUser: true)
        ) {
            ClipboardHistoryFeature()
        }

        // ❌ 修正前のコード: sheet 展開時に値型コピーを取る
        let staleCopy = store.state.items.first(where: { $0.id == item.id })!
        XCTAssertFalse(staleCopy.isFavorite, "コピー取得時点では false")

        await store.send(.toggleFavorite(item)) {
            $0.items[0].isFavorite = true
        }
        await store.receive(\.saveItems)

        // Store は更新されているが、値型コピーは古いまま（バグの原因）
        XCTAssertFalse(
            staleCopy.isFavorite,
            "【バグの再現】値型コピーは toggle 後も false のまま。" +
            "これがシートの星アイコンが変わらなかった原因"
        )
        XCTAssertTrue(
            store.state.items[0].isFavorite,
            "Store 本体は正しく true に更新されている"
        )
        await store.finish()
    }

    /// 観点2b（リグレッション）: 修正後の正しいパターンを証明
    /// store.items.first(where: id) で引き直せば常に最新値が取れる
    func testToggleFavorite_lookupByIDReturnsLatestAfterToggle() async {
        let item = ClipboardItem(content: "Test", isFavorite: false)
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item], isProUser: true)
        ) {
            ClipboardHistoryFeature()
        }

        await store.send(.toggleFavorite(item)) {
            $0.items[0].isFavorite = true
        }
        await store.receive(\.saveItems)

        // ✅ 修正後のコード: IDで引き直す（ClipboardHistoryView / FavoritesView の修正箇所）
        let latestItem = store.state.items.first(where: { $0.id == item.id })

        XCTAssertNotNil(latestItem, "IDで引いたアイテムが存在する")
        XCTAssertTrue(
            latestItem!.isFavorite,
            "【修正の証明】IDで引き直すと最新の true が取れる。" +
            "store.items.first(where: { $0.id == sheetItem.id }) が正しい実装"
        )
        await store.finish()
    }

    // MARK: - Trash Operations Tests (Pro user)

    func testRemoveItems_proUser_movesToTrashNotDelete() async {
        let item1 = ClipboardItem(content: "Item1")
        let item2 = ClipboardItem(content: "Item2")
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item1, item2], isProUser: true)
        ) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.removeItems(IndexSet([0])))

        XCTAssertEqual(store.state.items.count, 1, "アイテムがリストから削除されること")
        XCTAssertEqual(store.state.items.first?.id, item2.id, "item2が残ること")
        XCTAssertEqual(store.state.trashedItems.count, 1, "ゴミ箱にアイテムが追加されること")
        XCTAssertEqual(store.state.trashedItems.first?.id, item1.id, "item1がゴミ箱に移動されること")
        await store.finish()
    }

    func testRemoveItems_proUser_setsDeletedAt() async {
        let item = ClipboardItem(content: "Item")
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item], isProUser: true)
        ) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.removeItems(IndexSet([0])))

        XCTAssertNotNil(store.state.trashedItems.first?.deletedAt, "ゴミ箱移動時にdeletedAtが設定されること")
        await store.finish()
    }

    func testRestoreItem_movesFromTrashToItems() async {
        var trashedItem = ClipboardItem(content: "Trashed")
        trashedItem.deletedAt = Date()
        var initialState = ClipboardHistoryFeature.State()
        initialState.trashedItems = [trashedItem]
        initialState.isProUser = true
        let store = TestStore(initialState: initialState) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.restoreItem(trashedItem))

        XCTAssertTrue(store.state.trashedItems.isEmpty, "ゴミ箱からアイテムが取り除かれること")
        XCTAssertEqual(store.state.items.count, 1, "メインリストにアイテムが追加されること")
        XCTAssertNil(store.state.items.first?.deletedAt, "復元後はdeletedAtがクリアされること")
        await store.finish()
    }

    func testRestoreItem_updatesTimestamp() async {
        let oldDate = Date(timeIntervalSince1970: 0)
        var trashedItem = ClipboardItem(id: UUID(), content: "Trashed", timestamp: oldDate)
        trashedItem.deletedAt = Date()
        var initialState = ClipboardHistoryFeature.State()
        initialState.trashedItems = [trashedItem]
        initialState.isProUser = true
        let store = TestStore(initialState: initialState) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.restoreItem(trashedItem))

        XCTAssertGreaterThan(
            store.state.items.first?.timestamp ?? oldDate,
            oldDate,
            "復元時にタイムスタンプが現在時刻に更新されること"
        )
        await store.finish()
    }

    func testPermanentlyDeleteItem_removesFromTrash() async {
        var item1 = ClipboardItem(content: "Item1")
        var item2 = ClipboardItem(content: "Item2")
        item1.deletedAt = Date()
        item2.deletedAt = Date()
        var initialState = ClipboardHistoryFeature.State()
        initialState.trashedItems = [item1, item2]
        initialState.isProUser = true
        let store = TestStore(initialState: initialState) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.permanentlyDeleteItem(item1))

        XCTAssertEqual(store.state.trashedItems.count, 1, "指定アイテムのみ削除されること")
        XCTAssertEqual(store.state.trashedItems.first?.id, item2.id, "item2が残ること")
        await store.finish()
    }

    func testEmptyTrash_clearsAllTrashedItems() async {
        var item1 = ClipboardItem(content: "Item1")
        var item2 = ClipboardItem(content: "Item2")
        item1.deletedAt = Date()
        item2.deletedAt = Date()
        var initialState = ClipboardHistoryFeature.State()
        initialState.trashedItems = [item1, item2]
        initialState.isProUser = true
        let store = TestStore(initialState: initialState) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.emptyTrash)

        XCTAssertTrue(store.state.trashedItems.isEmpty, "ゴミ箱が空になること")
        await store.finish()
    }

    func testTrashLoaded_sortsByDeletedAtDescending() async {
        let now = Date()
        var older = ClipboardItem(content: "Older")
        var newer = ClipboardItem(content: "Newer")
        older.deletedAt = now.addingTimeInterval(-100)
        newer.deletedAt = now

        let store = TestStore(initialState: ClipboardHistoryFeature.State()) {
            ClipboardHistoryFeature()
        }

        await store.send(.trashLoaded([older, newer])) {
            $0.trashedItems = [newer, older]
        }
    }

    // MARK: - addItem Tests

    func testAddItem_freeUser_evictsOldestItemWhenOver20() async {
        // 実際の並び順（最新が先頭）で20件のアイテムを用意
        // addItem は末尾のアイテム（最古）を evict する
        let oldestItemID = UUID()
        let oldestItem = ClipboardItem(
            id: oldestItemID, content: "Oldest Item",
            timestamp: Date(timeIntervalSince1970: 0)
        )
        // 最新19件（降順）+ 最古1件 の順で並べる
        var existing = (1...19).map { i in
            ClipboardItem(id: UUID(), content: "Item \(i)",
                          timestamp: Date(timeIntervalSince1970: Double(20 - i)))
        }
        existing.append(oldestItem)  // 末尾 = 最古 = evict 対象

        let newItem = ClipboardItem(content: "New Item")
        var initialState = ClipboardHistoryFeature.State(items: existing, isProUser: false)
        initialState.captureCount = 0
        let store = TestStore(initialState: initialState) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.addItem(newItem))

        XCTAssertEqual(store.state.items.count, 20, "無料ユーザーは20件上限を超えないこと")
        XCTAssertEqual(store.state.items.first?.id, newItem.id, "新アイテムが先頭に入ること")
        XCTAssertFalse(
            store.state.items.contains(where: { $0.id == oldestItemID }),
            "最古のアイテムが追い出されること"
        )
        await store.finish()
    }

    func testAddItem_incrementsCaptureCount() async {
        let item = ClipboardItem(content: "Test")
        var initialState = ClipboardHistoryFeature.State()
        initialState.captureCount = 3
        let store = TestStore(initialState: initialState) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.addItem(item)) {
            $0.captureCount = 4
        }
        await store.finish()
    }

    // MARK: - Review Request Tests

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "clipkit.captureCount")
        UserDefaults.standard.removeObject(forKey: "clipkit.reviewMilestonesShown")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "clipkit.captureCount")
        UserDefaults.standard.removeObject(forKey: "clipkit.reviewMilestonesShown")
        super.tearDown()
    }

    func testCheckReviewTrigger_showsPromptAtCapture5() async {
        var state = ClipboardHistoryFeature.State()
        state.captureCount = 5
        let store = TestStore(initialState: state) {
            ClipboardHistoryFeature()
        }

        await store.send(.checkReviewTrigger) {
            $0.showSatisfactionPrompt = true
        }

        XCTAssertTrue(
            (UserDefaults.standard.stringArray(forKey: "clipkit.reviewMilestonesShown") ?? []).contains("capture5"),
            "capture5マイルストーンが記録されること"
        )
    }

    func testCheckReviewTrigger_showsPromptAtCapture20() async {
        UserDefaults.standard.set(["capture5"], forKey: "clipkit.reviewMilestonesShown")
        var state = ClipboardHistoryFeature.State()
        state.captureCount = 20
        let store = TestStore(initialState: state) {
            ClipboardHistoryFeature()
        }

        await store.send(.checkReviewTrigger) {
            $0.showSatisfactionPrompt = true
        }

        XCTAssertTrue(
            (UserDefaults.standard.stringArray(forKey: "clipkit.reviewMilestonesShown") ?? []).contains("capture20"),
            "capture20マイルストーンが記録されること"
        )
    }

    func testCheckReviewTrigger_showsPromptAtCapture50() async {
        UserDefaults.standard.set(["capture5", "capture20"], forKey: "clipkit.reviewMilestonesShown")
        var state = ClipboardHistoryFeature.State()
        state.captureCount = 50
        let store = TestStore(initialState: state) {
            ClipboardHistoryFeature()
        }

        await store.send(.checkReviewTrigger) {
            $0.showSatisfactionPrompt = true
        }

        XCTAssertTrue(
            (UserDefaults.standard.stringArray(forKey: "clipkit.reviewMilestonesShown") ?? []).contains("capture50"),
            "capture50マイルストーンが記録されること"
        )
    }

    func testCheckReviewTrigger_doesNotRepeatShownMilestone() async {
        UserDefaults.standard.set(["capture5"], forKey: "clipkit.reviewMilestonesShown")
        var state = ClipboardHistoryFeature.State()
        state.captureCount = 5
        let store = TestStore(initialState: state) {
            ClipboardHistoryFeature()
        }

        await store.send(.checkReviewTrigger)
        XCTAssertFalse(store.state.showSatisfactionPrompt, "表示済みマイルストーンは再表示しないこと")
    }

    func testCheckReviewTrigger_doesNotShowBefore5Captures() async {
        var state = ClipboardHistoryFeature.State()
        state.captureCount = 4
        let store = TestStore(initialState: state) {
            ClipboardHistoryFeature()
        }

        await store.send(.checkReviewTrigger)
        XCTAssertFalse(store.state.showSatisfactionPrompt, "5回未満では表示しないこと")
    }

    func testSatisfactionResponsePositive_sendsRequestReview() async {
        let store = TestStore(initialState: ClipboardHistoryFeature.State()) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.satisfactionResponsePositive)
        await store.receive(\.requestReview)
    }

    func testSatisfactionResponseNegative_showsFeedbackForm() async {
        let store = TestStore(initialState: ClipboardHistoryFeature.State()) {
            ClipboardHistoryFeature()
        }

        await store.send(.satisfactionResponseNegative) {
            $0.showFeedbackForm = true
        }
    }

    func testCopyItem_copyCountIncrementsEachTime() async {
        let item = ClipboardItem(content: "Test")
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item], copyCount: 0)
        ) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.copyItem(item)) { $0.copyCount = 1 }
        await store.send(.copyItem(item)) { $0.copyCount = 2 }
        await store.send(.copyItem(item)) { $0.copyCount = 3 }
        XCTAssertEqual(store.state.copyCount, 3)
        await store.finish()
    }

    // MARK: - Interstitial Ad wiring tests (issue #90)

    func testCopyItem_freeUser_notifiesInterstitialAd() async {
        let item = ClipboardItem(content: "Test")
        let pastedCalls = LockIsolated<[Bool]>([])
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item], isProUser: false)
        ) {
            ClipboardHistoryFeature()
        } withDependencies: {
            $0.interstitialAd.onItemPasted = { isProUser in
                pastedCalls.withValue { $0.append(isProUser) }
            }
        }
        store.exhaustivity = .off

        await store.send(.copyItem(item))
        await store.finish()

        XCTAssertEqual(pastedCalls.value, [false], "copyItemでonItemPastedがisProUser=falseで呼ばれること")
    }

    func testCopyItem_proUser_notifiesInterstitialAdWithProFlag() async {
        let item = ClipboardItem(content: "Test")
        let pastedCalls = LockIsolated<[Bool]>([])
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item], isProUser: true)
        ) {
            ClipboardHistoryFeature()
        } withDependencies: {
            $0.interstitialAd.onItemPasted = { isProUser in
                pastedCalls.withValue { $0.append(isProUser) }
            }
        }
        store.exhaustivity = .off

        await store.send(.copyItem(item))
        await store.finish()

        XCTAssertEqual(pastedCalls.value, [true], "ProユーザーではisProUser=trueで呼ばれること（表示可否はManager側で判定）")
    }

    func testCopyTransformedText_notifiesInterstitialAd() async {
        let pastedCalls = LockIsolated<[Bool]>([])
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(isProUser: false)
        ) {
            ClipboardHistoryFeature()
        } withDependencies: {
            $0.interstitialAd.onItemPasted = { isProUser in
                pastedCalls.withValue { $0.append(isProUser) }
            }
        }
        store.exhaustivity = .off

        await store.send(.copyTransformedText("HELLO", .uppercase))
        await store.finish()

        XCTAssertEqual(pastedCalls.value, [false], "copyTransformedTextでonItemPastedが呼ばれること")
    }

    func testPasteItem_notifiesInterstitialAd() async {
        let item = ClipboardItem(content: "Test")
        let pastedCalls = LockIsolated<[Bool]>([])
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item], isProUser: false)
        ) {
            ClipboardHistoryFeature()
        } withDependencies: {
            $0.interstitialAd.onItemPasted = { isProUser in
                pastedCalls.withValue { $0.append(isProUser) }
            }
        }
        store.exhaustivity = .off

        await store.send(.pasteItem(item))
        await store.finish()

        XCTAssertEqual(pastedCalls.value, [false], "pasteItemでonItemPastedが呼ばれること")
    }

    // MARK: - Duplicate detection tests

    func testCheckClipboard_duplicateText_stateHasCorrectFirst() {
        // 重複検知: items.first のテキストと一致する場合はスキップされることを確認するため、
        // State の items.first が正しく参照できることを検証
        let existingItem = ClipboardItem(content: "Hello")
        let state = ClipboardHistoryFeature.State(items: [existingItem], isProUser: true)
        XCTAssertEqual(state.items.first?.textContent, "Hello")
        XCTAssertEqual(state.items.first?.type, .text)
    }

    // MARK: - Category Filter Tests

    func testFilteredItems_withCategorySelected_showsOnlyMatchingItems() {
        let textItem = ClipboardItem(
            id: UUID(), timestamp: Date(), type: .text,
            textContent: "hello", category: .text
        )
        let urlItem = ClipboardItem(
            id: UUID(), timestamp: Date(), type: .url,
            url: URL(string: "https://example.com"), category: .url
        )
        var state = ClipboardHistoryFeature.State(items: [textItem, urlItem], isProUser: true)
        state.selectedCategory = .url
        XCTAssertEqual(state.filteredItems.count, 1)
        XCTAssertEqual(state.filteredItems.first?.category, .url)
    }

    func testFilteredItems_withNoCategorySelected_showsAllItems() {
        let textItem = ClipboardItem(
            id: UUID(), timestamp: Date(), type: .text,
            textContent: "hello", category: .text
        )
        let urlItem = ClipboardItem(
            id: UUID(), timestamp: Date(), type: .url,
            url: URL(string: "https://example.com"), category: .url
        )
        var state = ClipboardHistoryFeature.State(items: [textItem, urlItem], isProUser: true)
        state.selectedCategory = nil
        XCTAssertEqual(state.filteredItems.count, 2)
    }

    func testSelectCategory_updatesState() async {
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(isProUser: true)
        ) {
            ClipboardHistoryFeature()
        }

        await store.send(.selectCategory(.url)) {
            $0.selectedCategory = .url
        }

        await store.send(.selectCategory(nil)) {
            $0.selectedCategory = nil
        }
    }

    // MARK: - updateItemOCR Tests

    func testUpdateItemOCR_setsOCRTextAndCategory() async {
        let imageItem = ClipboardItem(
            id: UUID(), timestamp: Date(), type: .image,
            imageData: UIImage().pngData()
        )
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [imageItem], isProUser: true)
        ) {
            ClipboardHistoryFeature()
        }

        await store.send(.updateItemOCR(id: imageItem.id, ocrText: "extracted text", category: .text)) {
            $0.items[0].ocrText = "extracted text"
            $0.items[0].category = .text
        }

        await store.receive(\.saveItems)
        await store.finish()
    }

    func testUpdateItemOCR_ignoresUnknownID() async {
        let imageItem = ClipboardItem(
            id: UUID(), timestamp: Date(), type: .image
        )
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [imageItem], isProUser: true)
        ) {
            ClipboardHistoryFeature()
        }

        // IDが一致しない場合もstateは変わらないが、saveItemsは送出される
        await store.send(.updateItemOCR(id: UUID(), ocrText: "text", category: nil))
        await store.receive(\.saveItems)
        await store.finish()
    }

    // MARK: - OCR search via filteredItems

    func testFilteredItems_searchMatchesOCRText() {
        let imageItem = ClipboardItem(
            id: UUID(), timestamp: Date(), type: .image,
            ocrText: "請求書 2024年"
        )
        var state = ClipboardHistoryFeature.State(items: [imageItem], isProUser: true)
        state.searchText = "請求書"
        XCTAssertEqual(state.filteredItems.count, 1)
        state.searchText = "存在しないテキスト"
        XCTAssertEqual(state.filteredItems.count, 0)
    }
}
