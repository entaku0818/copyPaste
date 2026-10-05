import XCTest
import ComposableArchitecture
@testable import ClipKit

// MARK: - 課金画面の入口別計測のテスト（issue #109）

@MainActor
final class PaywallTrackingTests: XCTestCase {

    /// 送られた source を記録するクライアントを差し込んだ TestStore を作る
    private func makeStore(
        _ state: ClipboardHistoryFeature.State,
        logged: LockIsolated<[PaywallSource]>
    ) -> TestStoreOf<ClipboardHistoryFeature> {
        TestStore(initialState: state) {
            ClipboardHistoryFeature()
        } withDependencies: {
            $0.paywallAnalytics.logShown = { source in
                logged.withValue { $0.append(source) }
            }
        }
    }

    // MARK: - イベント仕様

    func testSourceRawValues_matchEventSpec() {
        // GA4に送る値。変えると入口別CVRの時系列が途切れるので固定する
        XCTAssertEqual(
            PaywallSource.allCases.map(\.rawValue),
            [
                "history_banner",
                "favorite_limit",
                "snippet_limit",
                "keyboard",
                "text_transform",
                "snippets_add_button",
                "settings_hero",
                "favorites_banner"
            ]
        )
    }

    // MARK: - reducer内で上限に達した入口

    func testFavoriteLimit_logsFavoriteLimitSource() async {
        let favorites = (0..<10).map { ClipboardItem(content: "Favorite \($0)", isFavorite: true) }
        let newItem = ClipboardItem(content: "New Item", isFavorite: false)
        let logged = LockIsolated<[PaywallSource]>([])
        let store = makeStore(
            ClipboardHistoryFeature.State(items: favorites + [newItem], isProUser: false),
            logged: logged
        )

        await store.send(.toggleFavorite(newItem))
        await store.receive(\.showPaywall) {
            $0.showPaywall = true
        }

        XCTAssertEqual(logged.value, [.favoriteLimit])
    }

    func testSnippetLimit_logsSnippetLimitSource() async {
        var state = ClipboardHistoryFeature.State(isProUser: false)
        state.snippets = (0..<3).map {
            Snippet(title: "Snippet \($0)", content: "Content \($0)", sortOrder: Int64($0))
        }
        let logged = LockIsolated<[PaywallSource]>([])
        let store = makeStore(state, logged: logged)
        store.exhaustivity = .off

        await store.send(.addSnippet(title: "4件目", content: "追加できないはず"))
        await store.receive(\.showPaywall) {
            $0.showPaywall = true
        }

        XCTAssertEqual(logged.value, [.snippetLimit])
    }

    // MARK: - store.showPaywall で開く入口（履歴バナー・キーボード）

    func testShowPaywall_logsGivenSourceAndPresents() async {
        for source in [PaywallSource.historyBanner, .keyboard] {
            let logged = LockIsolated<[PaywallSource]>([])
            let store = makeStore(ClipboardHistoryFeature.State(isProUser: false), logged: logged)

            await store.send(.showPaywall(source)) {
                $0.showPaywall = true
            }

            XCTAssertEqual(logged.value, [source], "\(source.rawValue) で開いたらそのsourceで1回送ること")
        }
    }

    // MARK: - View側の@Stateシートで開く入口

    func testPaywallShownLocally_logsWithoutPresentingStoreSheet() async {
        // 設定・お気に入り・スニペットタブ・テキスト変換はView側のシートで開くので、
        // storeのシート状態は触らず計測だけ行う（二重に課金画面が出ないこと）
        for source in [PaywallSource.textTransform, .snippetsAddButton, .settingsHero, .favoritesBanner] {
            let logged = LockIsolated<[PaywallSource]>([])
            let store = makeStore(ClipboardHistoryFeature.State(isProUser: false), logged: logged)

            await store.send(.paywallShownLocally(source))

            XCTAssertFalse(store.state.showPaywall)
            XCTAssertEqual(logged.value, [source], "\(source.rawValue) で開いたらそのsourceで1回送ること")
        }
    }

    func testDismissPaywall_doesNotLog() async {
        let logged = LockIsolated<[PaywallSource]>([])
        let store = makeStore(ClipboardHistoryFeature.State(isProUser: false), logged: logged)
        store.exhaustivity = .off

        await store.send(.showPaywall(.historyBanner))
        await store.send(.dismissPaywall)
        await store.skipReceivedActions()

        XCTAssertEqual(logged.value, [.historyBanner], "閉じたときは送らないこと")
    }
}
