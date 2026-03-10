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
        let item = ClipboardItem(content: "Test", isFavorite: false)

        let store = TestStore(initialState: ClipboardHistoryFeature.State(items: [item], isProUser: false)) {
            ClipboardHistoryFeature()
        }

        await store.send(.toggleFavorite(item))
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
