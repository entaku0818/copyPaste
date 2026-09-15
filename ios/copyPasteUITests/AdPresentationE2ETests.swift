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

    /// - Parameters:
    ///   - resetAdState: 表示回数・クールダウンを初期化するか。
    ///     永続化しているので、前の状態を引き継ぎたい時だけfalseにする。
    ///   - seedInterstitial: コピー5回ぶんを仕込んで、タブ切替だけで
    ///     インタースティシャルを出せる状態にするか。
    private func makeApp(resetAdState: Bool = true, seedInterstitial: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        // オンボーディングを飛ばす（NSArgumentDomain経由でUserDefaultsを上書き）
        var args = ["-hasCompletedOnboarding", "YES"]
        if resetAdState {
            args.append("--reset-ad-state")
        }
        if seedInterstitial {
            args.append("--seed-interstitial-ready")
        }
        app.launchArguments = args
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 全画面広告が出ているか。
    ///
    /// 出方がフォーマットで違う:
    /// - App Open はアプリの上に乗るので、タブバーは階層に残ったまま操作不能になる
    /// - インタースティシャルは画面ごと置き換えるので、タブバーが階層から消える
    ///
    /// どちらも「アプリのタブバーが叩けない」で捉えられる。`exists` を条件に入れると
    /// インタースティシャルを取りこぼすので見ない（実際にそれで偽陰性を出した）。
    private func fullScreenAdIsVisible(_ app: XCUIApplication) -> Bool {
        !app.tabBars.buttons["履歴"].isHittable
    }

    private func report(_ app: XCUIApplication, _ tag: String) {
        attach(app, tag)
        let tab = app.tabBars.buttons["履歴"]
        print("E2E_STATE \(tag) webViews=\(app.webViews.count) tabExists=\(tab.exists) " +
              "tabHittable=\(tab.isHittable) adVisible=\(fullScreenAdIsVisible(app))")
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

    // MARK: - Interstitial

    /// コピー回数が閾値に達している状態でタブを切り替えると、
    /// インタースティシャルが実際に画面へ出ること。
    ///
    /// `ContentView` の `.onChange(of: selectedTab)` → `.tabChanged` →
    /// `showPendingAd` という、ユニットテストからは触れないSwiftUIの配線を通す。
    @MainActor
    func testInterstitialAppearsOnTabSwitch() throws {
        let app = makeApp(seedInterstitial: true)
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 20)
        sleep(6)
        report(app, "inter_before_tab_switch")
        XCTAssertFalse(fullScreenAdIsVisible(app), "タブを切り替えるまでは出さないこと")

        app.tabBars.buttons["お気に入り"].tap()
        sleep(8)
        report(app, "inter_after_tab_switch")

        XCTAssertTrue(
            fullScreenAdIsVisible(app),
            "タブ切り替えでインタースティシャルが画面に出ること"
        )
    }

    // MARK: - 相互排他

    /// App Open広告を出した直後は、条件が揃っていてもタブ切り替えで
    /// インタースティシャルを出さないこと（2枚続けて出る事故の回帰テスト）
    @MainActor
    func testInterstitialIsSuppressedRightAfterAppOpenAd() throws {
        // まずApp Open広告を出す
        let app = makeApp(seedInterstitial: true)
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 20)
        sleep(3)
        for _ in 1...4 {
            XCUIDevice.shared.press(.home)
            sleep(2)
            app.activate()
            _ = app.wait(for: .runningForeground, timeout: 20)
            sleep(6)
        }
        report(app, "mutex_appopen_shown")
        XCTAssertTrue(fullScreenAdIsVisible(app), "前提: App Open広告が出ていること")

        // 広告を閉じる代わりに入れ直さず再起動する。
        // 表示時刻はUserDefaultsに残るので、相互排他の条件はそのまま効く
        app.terminate()
        let relaunched = makeApp(resetAdState: false, seedInterstitial: true)
        relaunched.launch()
        _ = relaunched.wait(for: .runningForeground, timeout: 20)
        sleep(6)

        relaunched.tabBars.buttons["お気に入り"].tap()
        sleep(8)
        report(relaunched, "mutex_after_tab_switch")

        XCTAssertFalse(
            fullScreenAdIsVisible(relaunched),
            "App Open広告の直後はインタースティシャルを出さないこと（2枚続けて出る事故の防止）"
        )
    }
}
