import XCTest
import ComposableArchitecture
@testable import copyPaste

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

        // false → true
        await store.send(.toggleFavorite(item)) {
            $0.items[0].isFavorite = true
        }
        await store.receive(\.saveItems)

        XCTAssertTrue(
            store.state.items.first(where: { $0.id == item.id })!.isFavorite,
            "toggleFavorite後、IDで引いた値がtrueになっていること"
        )

        // true → false（二度押しで元に戻る）
        await store.send(.toggleFavorite(store.state.items[0])) {
            $0.items[0].isFavorite = false
        }
        await store.receive(\.saveItems)

        XCTAssertFalse(
            store.state.items.first(where: { $0.id == item.id })!.isFavorite,
            "再toggleFavorite後、IDで引いた値がfalseに戻ること"
        )
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
}
