import ComposableArchitecture
import XCTest
@testable import ClipKit

final class SaveToClipKitIntentTests: XCTestCase {
    private let storage = ClipboardStorageManager.shared

    func testBlankInputIsRejected() {
        XCTAssertThrowsError(try SaveToClipKitIntent.makeItem(from: ""))
        XCTAssertThrowsError(try SaveToClipKitIntent.makeItem(from: " \t\n"))
    }

    func testTextKeepsWhitespaceAndUsesExistingCategoryDetection() throws {
        let text = "  user@example.com\n"

        let item = try SaveToClipKitIntent.makeItem(from: text)

        XCTAssertEqual(item.type, .text)
        XCTAssertEqual(item.textContent, text)
        XCTAssertEqual(item.category, .email)
    }

    func testWholeWebURLIsSavedAsURL() throws {
        let url = "https://example.com/a%20b?q=clipkit#history"

        let item = try SaveToClipKitIntent.makeItem(from: url)

        XCTAssertEqual(item.type, .url)
        XCTAssertEqual(item.url?.absoluteString, url)
        XCTAssertEqual(item.category, .url)
    }

    func testTextContainingAWebURLRemainsText() throws {
        let text = "https://example.com is the site to check."

        let item = try SaveToClipKitIntent.makeItem(from: text)

        XCTAssertEqual(item.type, .text)
        XCTAssertEqual(item.textContent, text)
    }

    @MainActor
    func testPerformWritesInputToHistory() async throws {
        try await storage.clearAll()
        let intent = SaveToClipKitIntent()
        intent.text = "Shared from Shortcuts"

        _ = try await intent.perform()

        let items = try await storage.load()
        XCTAssertEqual(items.map(\.textContent), ["Shared from Shortcuts"])
    }

    @MainActor
    func testAlreadyOpenHistoryReflectsSaveWithoutReplacingOtherItems() async {
        let favorite = ClipboardItem(content: "favorite", isFavorite: true)
        let removed = ClipboardItem(content: "removed")
        let buffered = ClipboardItem(content: "buffered")
        let shared = ClipboardItem(content: "shared", timestamp: Date().addingTimeInterval(1))
        let store = TestStore(
            initialState: ClipboardHistoryFeature.State(items: [favorite, buffered, removed])
        ) {
            ClipboardHistoryFeature()
        }

        await store.send(.sharedItemSaved(shared, removedIDs: [removed.id])) {
            $0.items = [favorite, shared, buffered]
        }
        await store.finish()
    }

    @MainActor
    func testUnboundedSavePreservesExistingHistory() async throws {
        try await storage.clearAll()
        let original = ClipboardItem(content: "existing item", isFavorite: true)
        try await storage.save(items: [original])

        let shared = try SaveToClipKitIntent.makeItem(from: "https://example.com")
        let pruned = try await storage.saveSharedItem(shared, limit: nil)

        let items = try await storage.load()
        XCTAssertTrue(pruned.isEmpty)
        XCTAssertEqual(Set(items.map(\.id)), [original.id, shared.id])
        XCTAssertEqual(items.first(where: { $0.id == original.id })?.isFavorite, true)
        XCTAssertEqual(items.first(where: { $0.id == shared.id })?.url, shared.url)
    }

    @MainActor
    func testLimitedSaveRetainsFavoritesAndRecentItemsWithoutChangingTrash() async throws {
        try await storage.clearAll()
        let favorite = ClipboardItem(content: "favorite", timestamp: Date(timeIntervalSince1970: 1), isFavorite: true)
        let older = ClipboardItem(content: "older", timestamp: Date(timeIntervalSince1970: 2))
        let recent = ClipboardItem(content: "recent", timestamp: Date(timeIntervalSince1970: 3))
        var trashed = ClipboardItem(content: "trashed")
        trashed.deletedAt = Date(timeIntervalSince1970: 4)
        try await storage.save(items: [favorite, older, recent])
        try await storage.saveTrash(items: [trashed])

        let shared = ClipboardItem(content: "new shared item")
        let pruned = try await storage.saveSharedItem(shared, limit: 3)

        let items = try await storage.load()
        let trash = try await storage.loadTrash()
        XCTAssertEqual(pruned, [older.id])
        XCTAssertEqual(Set(items.map(\.id)), [favorite.id, recent.id, shared.id])
        XCTAssertEqual(trash.map(\.id), [trashed.id])
        XCTAssertEqual(trash.first?.deletedAt, trashed.deletedAt)
    }

    @MainActor
    func testConcurrentLimitedSavesKeepBothNewItems() async throws {
        try await storage.clearAll()
        let older = ClipboardItem(content: "older", timestamp: Date(timeIntervalSince1970: 1))
        let recent = ClipboardItem(content: "recent", timestamp: Date(timeIntervalSince1970: 2))
        try await storage.save(items: [older, recent])

        let first = ClipboardItem(content: "first shared item")
        let second = ClipboardItem(content: "second shared item")
        async let firstResult = storage.saveSharedItem(first, limit: 2)
        async let secondResult = storage.saveSharedItem(second, limit: 2)
        let (firstPruned, secondPruned) = try await (firstResult, secondResult)

        let items = try await storage.load()
        XCTAssertEqual(firstPruned.union(secondPruned), [older.id, recent.id])
        XCTAssertEqual(Set(items.map(\.id)), [first.id, second.id])
    }
}
