import XCTest
import ComposableArchitecture
@testable import copyPaste

@MainActor
final class ClipboardHistoryFeatureTests: XCTestCase {

    // MARK: - Favorite Functionality Tests

    func testToggleFavorite_makesItemFavorite() async {
        let item = ClipboardItem(content: "Test", isFavorite: false)

        let store = TestStore(initialState: ClipboardHistoryFeature.State(items: [item])) {
            ClipboardHistoryFeature()
        }

        await store.send(.toggleFavorite(item)) {
            $0.items[0].isFavorite = true
        }

        await store.receive(.saveItems)
    }

    func testToggleFavorite_unfavoritesItem() async {
        let item = ClipboardItem(content: "Test", isFavorite: true)

        let store = TestStore(initialState: ClipboardHistoryFeature.State(items: [item])) {
            ClipboardHistoryFeature()
        }

        await store.send(.toggleFavorite(item)) {
            $0.items[0].isFavorite = false
        }

        await store.receive(.saveItems)
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
            initialState: ClipboardHistoryFeature.State(items: [item2, item1])
        ) {
            ClipboardHistoryFeature()
        }

        // Toggle favorite on the second item (older one)
        await store.send(.toggleFavorite(item1)) {
            // After toggling, item1 should be first (favorite), then item2
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

        await store.receive(.saveItems)
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
            initialState: ClipboardHistoryFeature.State(items: [item3, item1, item2])
        ) {
            ClipboardHistoryFeature()
        }

        // Toggle favorite on item2 (make it favorite)
        await store.send(.toggleFavorite(item2)) {
            // All items are now favorite, sorted by timestamp descending
            $0.items = [
                item3, // 300, favorite
                ClipboardItem(
                    id: item2.id,
                    content: "Second",
                    timestamp: Date(timeIntervalSince1970: 200),
                    isFavorite: true
                ), // 200, favorite
                item1  // 100, favorite
            ]
        }

        await store.receive(.saveItems)
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

        let store = TestStore(initialState: ClipboardHistoryFeature.State()) {
            ClipboardHistoryFeature()
        }

        await store.send(.itemsLoaded([item1, item2, item3])) {
            // item2 should be first (favorite), then item1, then item3
            $0.items = [item2, item1, item3]
        }
    }

    // MARK: - Helper Methods Tests

    func testToggleFavorite_nonExistentItem_doesNothing() async {
        let item1 = ClipboardItem(content: "Test")
        let item2 = ClipboardItem(content: "Other")

        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [item1])
        ) {
            ClipboardHistoryFeature()
        }

        // Try to toggle a non-existent item
        await store.send(.toggleFavorite(item2))
        // No state change expected
    }
}
