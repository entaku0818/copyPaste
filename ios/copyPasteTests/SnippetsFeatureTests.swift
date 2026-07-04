import XCTest
import ComposableArchitecture
@testable import ClipKit

// MARK: - スニペット（定型文）機能のテスト（issue #85）

@MainActor
final class SnippetsFeatureTests: XCTestCase {

    // MARK: - 追加

    func testAddSnippet_appendsWithSequentialSortOrder() async {
        let store = TestStore(initialState: ClipboardHistoryFeature.State(isProUser: false)) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.addSnippet(title: "挨拶", content: "お世話になっております。"))
        await store.send(.addSnippet(title: "署名", content: "ClipKit運営"))
        await store.send(.addSnippet(title: "日付", content: "本日は{日付}です"))
        await store.finish()

        XCTAssertEqual(store.state.snippets.count, 3, "無料ユーザーでも3件までは追加できること")
        XCTAssertEqual(store.state.snippets.map(\.sortOrder), [0, 1, 2], "sortOrderが追加順に振られること")
        XCTAssertFalse(store.state.showPaywall, "3件まではPaywallが表示されないこと")
    }

    func testAddSnippet_freeUser_fourthShowsPaywall() async {
        var state = ClipboardHistoryFeature.State(isProUser: false)
        state.snippets = (0..<3).map {
            Snippet(title: "Snippet \($0)", content: "Content \($0)", sortOrder: Int64($0))
        }
        let store = TestStore(initialState: state) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.addSnippet(title: "4件目", content: "追加できないはず"))
        await store.receive(\.showPaywall) {
            $0.showPaywall = true
        }
        await store.finish()

        XCTAssertEqual(store.state.snippets.count, 3, "無料ユーザーは4件目を追加できないこと")
    }

    func testAddSnippet_proUser_hasNoLimit() async {
        var state = ClipboardHistoryFeature.State(isProUser: true)
        state.snippets = (0..<3).map {
            Snippet(title: "Snippet \($0)", content: "Content \($0)", sortOrder: Int64($0))
        }
        let store = TestStore(initialState: state) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.addSnippet(title: "4件目", content: "Proは無制限"))
        await store.finish()

        XCTAssertEqual(store.state.snippets.count, 4, "Proユーザーは4件以上追加できること")
        XCTAssertFalse(store.state.showPaywall)
    }

    func testAddSnippet_persistsViaSaveSnippets() async {
        let savedSnippets = LockIsolated<[[Snippet]]>([])
        let store = TestStore(initialState: ClipboardHistoryFeature.State(isProUser: false)) {
            ClipboardHistoryFeature()
        } withDependencies: {
            $0.snippetRepository.save = { snippets in
                savedSnippets.withValue { $0.append(snippets) }
            }
        }
        store.exhaustivity = .off

        await store.send(.addSnippet(title: "挨拶", content: "こんにちは"))
        await store.finish()

        XCTAssertEqual(savedSnippets.value.count, 1, "追加時に保存が呼ばれること")
        XCTAssertEqual(savedSnippets.value.first?.first?.content, "こんにちは")
    }

    // MARK: - 編集

    func testUpdateSnippet_replacesContentAndBumpsUpdatedAt() async {
        let oldDate = Date(timeIntervalSince1970: 0)
        let snippet = Snippet(
            title: "旧タイトル", content: "旧本文",
            sortOrder: 0, createdAt: oldDate, updatedAt: oldDate
        )
        var state = ClipboardHistoryFeature.State(isProUser: false)
        state.snippets = [snippet]
        let store = TestStore(initialState: state) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        var edited = snippet
        edited.title = "新タイトル"
        edited.content = "新本文"
        await store.send(.updateSnippet(edited))
        await store.finish()

        XCTAssertEqual(store.state.snippets.first?.title, "新タイトル")
        XCTAssertEqual(store.state.snippets.first?.content, "新本文")
        XCTAssertGreaterThan(
            store.state.snippets.first?.updatedAt ?? oldDate, oldDate,
            "更新時にupdatedAtが更新されること"
        )
    }

    func testUpdateSnippet_unknownID_doesNothing() async {
        var state = ClipboardHistoryFeature.State(isProUser: false)
        state.snippets = [Snippet(title: "A", content: "a")]
        let store = TestStore(initialState: state) {
            ClipboardHistoryFeature()
        }

        await store.send(.updateSnippet(Snippet(title: "B", content: "b")))
        XCTAssertEqual(store.state.snippets.first?.title, "A", "存在しないIDの更新は無視されること")
    }

    // MARK: - 削除・並び替え

    func testDeleteSnippets_removesAndRenumbers() async {
        var state = ClipboardHistoryFeature.State(isProUser: false)
        state.snippets = (0..<3).map {
            Snippet(title: "Snippet \($0)", content: "Content \($0)", sortOrder: Int64($0))
        }
        let store = TestStore(initialState: state) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        await store.send(.deleteSnippets(IndexSet(integer: 0)))
        await store.finish()

        XCTAssertEqual(store.state.snippets.count, 2)
        XCTAssertEqual(store.state.snippets.map(\.title), ["Snippet 1", "Snippet 2"])
        XCTAssertEqual(store.state.snippets.map(\.sortOrder), [0, 1], "削除後にsortOrderが振り直されること")
    }

    func testMoveSnippets_reordersAndRenumbers() async {
        var state = ClipboardHistoryFeature.State(isProUser: false)
        state.snippets = (0..<3).map {
            Snippet(title: "Snippet \($0)", content: "Content \($0)", sortOrder: Int64($0))
        }
        let store = TestStore(initialState: state) {
            ClipboardHistoryFeature()
        }
        store.exhaustivity = .off

        // 先頭を末尾へ移動
        await store.send(.moveSnippets(IndexSet(integer: 0), 3))
        await store.finish()

        XCTAssertEqual(
            store.state.snippets.map(\.title),
            ["Snippet 1", "Snippet 2", "Snippet 0"],
            "並び替えが反映されること"
        )
        XCTAssertEqual(store.state.snippets.map(\.sortOrder), [0, 1, 2], "並び替え後にsortOrderが振り直されること")
    }

    // MARK: - 読み込み

    func testSnippetsLoaded_sortsBySortOrder() async {
        let first = Snippet(title: "先頭", content: "a", sortOrder: 0)
        let second = Snippet(title: "2番目", content: "b", sortOrder: 1)
        let third = Snippet(title: "3番目", content: "c", sortOrder: 2)
        let store = TestStore(initialState: ClipboardHistoryFeature.State()) {
            ClipboardHistoryFeature()
        }

        await store.send(.snippetsLoaded([third, first, second])) {
            $0.snippets = [first, second, third]
        }
    }

    func testLoadSnippets_deliversRepositoryContents() async {
        let stored = [Snippet(title: "保存済み", content: "内容", sortOrder: 0)]
        let store = TestStore(initialState: ClipboardHistoryFeature.State()) {
            ClipboardHistoryFeature()
        } withDependencies: {
            $0.snippetRepository.load = { stored }
        }

        await store.send(.loadSnippets)
        await store.receive(\.snippetsLoaded) {
            $0.snippets = stored
        }
        await store.finish()
    }

    // MARK: - 件数制限のState

    func testCanAddSnippet_freeUserLimitIs3() {
        var state = ClipboardHistoryFeature.State(isProUser: false)
        XCTAssertTrue(state.canAddSnippet)
        state.snippets = (0..<3).map { Snippet(content: "c\($0)") }
        XCTAssertFalse(state.canAddSnippet, "無料ユーザーは3件で追加不可になること")
        state.isProUser = true
        XCTAssertTrue(state.canAddSnippet, "Proになれば追加可能になること")
    }
}

// MARK: - 変数プレースホルダ展開のテスト

final class SnippetVariableExpanderTests: XCTestCase {

    private let fixedDate = Date(timeIntervalSince1970: 1_720_000_000)
    private let locale = Locale(identifier: "ja_JP")
    private let timeZone = TimeZone(identifier: "Asia/Tokyo")!

    private var expectedDateString: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: fixedDate)
    }

    private var expectedTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: fixedDate)
    }

    func testExpand_replacesJapanesePlaceholders() {
        let result = SnippetVariableExpander.expand(
            "本日{日付} {時刻}に伺います",
            date: fixedDate, locale: locale, timeZone: timeZone
        )
        XCTAssertEqual(result, "本日\(expectedDateString) \(expectedTimeString)に伺います")
    }

    func testExpand_replacesEnglishPlaceholders() {
        let result = SnippetVariableExpander.expand(
            "Date: {date}, Time: {time}",
            date: fixedDate, locale: locale, timeZone: timeZone
        )
        XCTAssertEqual(result, "Date: \(expectedDateString), Time: \(expectedTimeString)")
    }

    func testExpand_replacesRepeatedPlaceholders() {
        let result = SnippetVariableExpander.expand(
            "{日付}/{日付}",
            date: fixedDate, locale: locale, timeZone: timeZone
        )
        XCTAssertEqual(result, "\(expectedDateString)/\(expectedDateString)")
    }

    func testExpand_leavesUnknownPlaceholdersUntouched() {
        let result = SnippetVariableExpander.expand(
            "{名前}様 {日付}",
            date: fixedDate, locale: locale, timeZone: timeZone
        )
        XCTAssertEqual(result, "{名前}様 \(expectedDateString)")
    }

    func testExpand_plainTextIsUnchanged() {
        XCTAssertEqual(
            SnippetVariableExpander.expand("プレースホルダなしの本文"),
            "プレースホルダなしの本文"
        )
    }
}
