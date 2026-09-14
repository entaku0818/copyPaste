import XCTest

/// 全画面広告（App Open / インタースティシャル）が**実際に画面へ出るか**を確かめるE2E。
///
/// ユニットテストは表示判定のロジックしか見ていないため、`present(from:)` が本当に
/// 画面へ出るかは別途確かめる必要がある（実際に「presentを呼んでいるのに一度も出ない」
/// 不具合が起きていた）。
///
/// AdMobの実広告を取りに行くためネットワークに依存する。通常のCI/ローカルの
/// `xcodebuild test` では自動的にスキップし、環境変数を付けた時だけ走らせる:
///
///   TEST_RUNNER_CLIPKIT_AD_E2E=1 xcodebuild test -project ios/copyPaste.xcodeproj \
///     -scheme ClipKit -destination "id=<SIMULATOR_UDID>" \
///     -only-testing:ClipKitUITests/AdPresentationE2ETests
///
/// `TEST_RUNNER_` の接頭辞が要る（xcodebuildの引数として渡してもテストランナーには届かない）。
final class AdPresentationE2ETests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CLIPKIT_AD_E2E"] == "1",
            "広告E2Eはネットワーク依存のため、CLIPKIT_AD_E2E=1 の時だけ実行する"
        )
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        // オンボーディングを飛ばす（NSArgumentDomain経由でUserDefaultsを上書き）
        // オンボーディングを飛ばし、広告の表示回数・クールダウンを毎回初期化する
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "--reset-ad-state"]
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 全画面広告が画面を覆っているか。
    /// 覆われるとアプリ自身のタブバーが操作不能になるので、それを判定に使う。
    private func fullScreenAdIsVisible(_ app: XCUIApplication) -> Bool {
        let tab = app.tabBars.buttons["履歴"]
        return tab.exists && !tab.isHittable
    }

    private func report(_ app: XCUIApplication, _ tag: String) {
        attach(app, tag)
        let tab = app.tabBars.buttons["履歴"]
        print("E2E_STATE \(tag) webViews=\(app.webViews.count) " +
              "tabHittable=\(tab.isHittable) adVisible=\(fullScreenAdIsVisible(app))")
    }

    /// クリップボード監視を動かして履歴に1件入れ、そのあと監視を止める。
    ///
    /// 監視タイマーが回っているとXCUITestの「アプリのidle待ち」が終わらず
    /// UIクエリがタイムアウトするため、アイテムを入れたら必ず止める。
    /// 権限アラートは「許可する」を押す（放っておくとXCUITestの既定処理が
    /// 「後で」を押してしまい、履歴に何も入らない）。
    @discardableResult
    private func seedHistoryItemWithMonitoring(_ app: XCUIApplication) throws -> String {
        // 常時起動タブを開くと MonitoringView.onAppear が startMonitoring を送る
        app.tabBars.buttons["常時起動"].tap()

        let allow = app.buttons["許可する"].firstMatch
        if allow.waitForExistence(timeout: 10) {
            allow.tap()
        }
        sleep(2)

        let text = "E2E-\(UUID().uuidString.prefix(6))"
        UIPasteboard.general.string = text
        sleep(6)

        // 監視を止めてアプリをidleにする
        let stopButton = app.buttons["Stop"].firstMatch
        if stopButton.waitForExistence(timeout: 10) {
            stopButton.tap()
        }
        sleep(2)

        app.tabBars.buttons["履歴"].tap()
        sleep(2)

        let row = app.staticTexts[text]
        XCTAssertTrue(row.waitForExistence(timeout: 20), "クリップボード監視が履歴にアイテムを取り込むこと")
        return text
    }

    /// 詳細シートを開いてコピーする
    private func copyItem(_ app: XCUIApplication, labelled text: String) {
        app.staticTexts[text].firstMatch.tap()
        let copyButton = app.buttons["コピー"].firstMatch
        XCTAssertTrue(copyButton.waitForExistence(timeout: 10), "詳細シートのコピーボタンが出ること")
        copyButton.tap()
        sleep(1)
    }

    // MARK: - App Open

    /// 5回目のフォアグラウンドでApp Open広告が実際に画面へ出ること
    @MainActor
    func testAppOpenAdAppearsOnFifthForeground() throws {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 20)
        sleep(3)
        XCTAssertFalse(fullScreenAdIsVisible(app), "起動直後には出さないこと")

        // 起動が1回目。あと4回フォアグラウンドにすると5回目になる
        for cycle in 1...4 {
            XCUIDevice.shared.press(.home)
            sleep(2)
            app.activate()
            _ = app.wait(for: .runningForeground, timeout: 20)
            sleep(6)
            report(app, "appopen_fg_\(cycle)")
            if cycle < 4 {
                XCTAssertFalse(fullScreenAdIsVisible(app), "\(cycle + 1)回目のフォアグラウンドでは出さないこと")
            }
        }

        XCTAssertTrue(fullScreenAdIsVisible(app), "5回目のフォアグラウンドでApp Open広告が画面に出ること")
    }

    // MARK: - Interstitial（未カバー）

    // インタースティシャルの実表示はXCUITestからは駆動できていない。
    // 履歴にアイテムを入れるにはクリップボード監視を動かす必要があるが、
    // 監視を始めるとXCUITestの「アプリのidle待ち」が終わらなくなり
    // （実測: 「許可する」タップ後のidle待ちに68秒、以降のUIクエリは
    //  31秒×3リトライで全てタイムアウト）、コピー操作まで到達できない。
    //
    // 現状インタースティシャルについて分かっていること:
    // - 表示判定は ClipboardHistoryFeatureTests / FullScreenAdCoordinatorTests でカバー済み
    // - present経路（topViewController解決 → canPresent → present → markPresented）は
    //   App Openと同じコードを共有しており、上のテストで実際に画面に出ることを確認済み
    // - 未確認なのは「コピー5回 → タブ切替」というトリガー経路のみ
    //
    // 進めるなら、監視を止めた状態で履歴へ直接アイテムを流し込むデバッグ用の
    // 起動引数を足すのが現実的。
}
