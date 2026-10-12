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
                "favorites_banner",
                "widget",
                "settings_trash",
                "settings_export",
                "settings_icloud",
                "onboarding_trial",
                "monthly_prompt"
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
            $0.paywallSource = .favoriteLimit
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
                $0.paywallSource = source
                $0.showPaywall = true
            }

            XCTAssertEqual(logged.value, [source], "\(source.rawValue) で開いたらそのsourceで1回送ること")
        }
    }

    // MARK: - View側の@Stateシートで開く入口

    func testPaywallShownLocally_logsWithoutPresentingStoreSheet() async {
        // テキスト変換は項目詳細シートの上にView側のシートで開くので、
        // storeのシート状態は触らず計測だけ行う（二重に課金画面が出ないこと）
        for source in [PaywallSource.textTransform] {
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

    // MARK: - 購入・復元・閉じるのイベント（issue #114）

    func testPaywallEventNames_matchEventSpec() {
        // GA4に送るイベント名。変えると時系列が途切れるので固定する
        XCTAssertEqual(
            PaywallEvent.allCases.map(\.rawValue),
            [
                "paywall_purchase_started",
                "paywall_purchase_completed",
                "paywall_purchase_pending",
                "paywall_purchase_cancelled",
                "paywall_purchase_failed",
                "paywall_restore_started",
                "paywall_restore_completed",
                "paywall_restore_failed",
                "paywall_dismissed"
            ]
        )
    }

    func testPurchaseOutcome_mapsToEvent() {
        XCTAssertEqual(PaywallEvent.forPurchase(.completed), .purchaseCompleted)
        XCTAssertEqual(PaywallEvent.forPurchase(.pending), .purchasePending)
        // キャンセルは失敗として数えない（シンプル録音で cancelled が0件・failed に混ざっていた）
        XCTAssertEqual(PaywallEvent.forPurchase(.cancelled), .purchaseCancelled)
        XCTAssertEqual(PaywallEvent.forPurchase(.failed(message: "x")), .purchaseFailed)
    }

    func testEventParameters_includeSourcePlanAndTrial() {
        let params = PaywallEventParameters(source: .keyboard, plan: .annual, trialEligible: true)
        XCTAssertEqual(params.dictionary, [
            "source": "keyboard",
            "plan": "annual",
            "trial_eligible": "true"
        ])
    }

    func testEventParameters_omitUnknownValues() {
        // プラン未読込のまま閉じた場合など。空文字を送らずキーごと省く
        var params = PaywallEventParameters(source: .settingsHero)
        params.purchased = false
        XCTAssertEqual(params.dictionary, [
            "source": "settings_hero",
            "purchased": "false"
        ])
    }

    func testEventParameters_lifetimeIsNotTrial() {
        let params = PaywallEventParameters(source: .historyBanner, plan: .lifetime, trialEligible: false)
        XCTAssertEqual(params.dictionary["plan"], "lifetime")
        XCTAssertEqual(params.dictionary["trial_eligible"], "false")
    }

    func testShowPaywall_remembersSourceForPurchaseEvents() async {
        let store = makeStore(ClipboardHistoryFeature.State(isProUser: false), logged: LockIsolated([]))
        await store.send(.showPaywall(.keyboard)) {
            $0.paywallSource = .keyboard
            $0.showPaywall = true
        }
    }

    // MARK: - store のシートで開く入口（issue #116: どのタブでも出す・閉じたら Pro 状態を更新）

    func testTabEntryPoints_presentStoreSheetWithSource() async {
        // 設定・お気に入り・スニペットタブの入口は store のシート（ContentView に付いている）で開く
        for source in [PaywallSource.settingsHero, .favoritesBanner, .snippetsAddButton,
                       .settingsTrash, .settingsExport, .settingsICloud, .widget] {
            let logged = LockIsolated<[PaywallSource]>([])
            let store = makeStore(ClipboardHistoryFeature.State(isProUser: false), logged: logged)

            await store.send(.showPaywall(source)) {
                $0.paywallSource = source
                $0.showPaywall = true
            }
            XCTAssertEqual(logged.value, [source])
        }
    }

    func testDismissPaywall_refreshesProStatus() async {
        let store = makeStore(ClipboardHistoryFeature.State(isProUser: false), logged: LockIsolated([]))
        store.exhaustivity = .off

        await store.send(.showPaywall(.settingsHero))
        await store.send(.dismissPaywall) {
            $0.showPaywall = false
        }
        await store.receive(\.updateProStatus)
    }

    // MARK: - clipkit://subscription の入口判定（issue #116）

    func testDeepLink_widgetSource() {
        XCTAssertEqual(PaywallSource.fromDeepLink(URL(string: "clipkit://subscription?source=widget")!), .widget)
    }

    func testDeepLink_withoutSourceIsKeyboard() {
        // 旧バージョンのキーボード拡張は source を付けずに開く
        XCTAssertEqual(PaywallSource.fromDeepLink(URL(string: "clipkit://subscription")!), .keyboard)
        XCTAssertEqual(PaywallSource.fromDeepLink(URL(string: "clipkit://subscription?source=unknown")!), .keyboard)
    }

    func testDeepLink_otherURLsAreIgnored() {
        XCTAssertNil(PaywallSource.fromDeepLink(URL(string: "clipkit://history")!))
        XCTAssertNil(PaywallSource.fromDeepLink(URL(string: "https://subscription")!))
    }
}
