import XCTest
@testable import ClipKit

/// システムレビューダイアログの提示先シーンの**選び方**を固定するテスト（issue #106）。
///
/// #106 の原因は `AppReview.requestSystemReview` がこう書かれていたこと:
///
///     UIApplication.shared.connectedScenes
///         .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
///
/// 「状態で1つ引いてから型変換する」順序になっているため、引いたシーンが
/// `UIWindowScene` でないとキャストに失敗して nil になり、ダイアログを出さずに
/// 無言終了する。`connectedScenes` は `Set<UIScene>` で順序が不定なので、
/// どちらが引かれるかは実行環境次第だった。
///
/// 非 `UIWindowScene` な `UIScene` はテスト内で生成できないため、
/// `AppReview.presentationScene(from:)` を実シーンで叩くだけではこの取り違えを
/// 再現できない。選び方だけを `AppReview.selectScene` に分離してもらったので、
/// ここではフェイクで「非WindowSceneが先に来る」並びを作って固定する。
final class AppReviewSceneSelectionTests: XCTestCase {

    /// UIScene の代役。`isWindowScene == false` は「UIWindowSceneではないシーン」を表す。
    private struct FakeScene: Equatable {
        let name: String
        let isWindowScene: Bool
        let isForegroundActive: Bool
    }

    private func select(_ scenes: [FakeScene]) -> FakeScene? {
        AppReview.selectScene(
            from: scenes,
            narrow: { $0.isWindowScene ? $0 : nil },
            isForegroundActive: { $0.isForegroundActive }
        )
    }

    // MARK: - #106 の取り違えの回帰テスト

    /// **これが #106 の核心。**
    ///
    /// foregroundActive だが UIWindowScene ではないシーンが先頭にある並び。
    /// 旧実装の順序（状態で引いてから型変換）だと先頭を引いてキャストに失敗し nil になる。
    /// 型で絞ってから状態で探せば、後ろにある本来の対象を正しく見つけられる。
    func testSelectScene_skipsForegroundActiveNonWindowSceneAndFindsWindowScene() {
        let scenes = [
            FakeScene(name: "non-window", isWindowScene: false, isForegroundActive: true),
            FakeScene(name: "main-window", isWindowScene: true, isForegroundActive: true)
        ]

        XCTAssertEqual(
            select(scenes)?.name, "main-window",
            "foregroundActiveな非WindowSceneが先頭にあっても、WindowSceneを見つけること"
            + "（ここがnilになるとダイアログが出ない = #106）"
        )
    }

    /// 並び順に依存しないこと。`Set` の順序は不定なので、どちらの順でも同じ結果でなければならない。
    func testSelectScene_isOrderIndependent() {
        let scenes = [
            FakeScene(name: "non-window", isWindowScene: false, isForegroundActive: true),
            FakeScene(name: "main-window", isWindowScene: true, isForegroundActive: true)
        ]

        XCTAssertEqual(
            select(scenes)?.name, select(scenes.reversed())?.name,
            "並び順を変えても同じシーンを選ぶこと"
        )
    }

    /// 非WindowSceneが複数先行していても辿り着けること。
    func testSelectScene_skipsMultipleNonWindowScenes() {
        let scenes = [
            FakeScene(name: "non-window-1", isWindowScene: false, isForegroundActive: true),
            FakeScene(name: "non-window-2", isWindowScene: false, isForegroundActive: true),
            FakeScene(name: "main-window", isWindowScene: true, isForegroundActive: true)
        ]

        XCTAssertEqual(select(scenes)?.name, "main-window")
    }

    // MARK: - 状態の条件が効いていること

    /// 型で絞る修正によって、状態の判定が緩くなっていないことを確認する。
    /// WindowSceneでもforegroundActiveでなければ選んではいけない。
    func testSelectScene_ignoresBackgroundedWindowScene() {
        let scenes = [
            FakeScene(name: "background-window", isWindowScene: true, isForegroundActive: false)
        ]

        XCTAssertNil(
            select(scenes),
            "WindowSceneでもforegroundActiveでなければ選ばないこと"
        )
    }

    /// foregroundActive なものが複数あれば、そのうちの WindowScene を選ぶ。
    func testSelectScene_picksForegroundWindowSceneAmongMixedStates() {
        let scenes = [
            FakeScene(name: "background-window", isWindowScene: true, isForegroundActive: false),
            FakeScene(name: "non-window", isWindowScene: false, isForegroundActive: true),
            FakeScene(name: "foreground-window", isWindowScene: true, isForegroundActive: true)
        ]

        XCTAssertEqual(select(scenes)?.name, "foreground-window")
    }

    // MARK: - 出せるシーンが無いケース

    func testSelectScene_returnsNilWhenEmpty() {
        XCTAssertNil(select([]))
    }

    /// WindowSceneが1つも無ければ nil。
    /// 呼び出し側はここで `review_system_dialog_skipped` をAnalyticsに記録する。
    func testSelectScene_returnsNilWhenNoWindowScene() {
        let scenes = [
            FakeScene(name: "non-window-1", isWindowScene: false, isForegroundActive: true),
            FakeScene(name: "non-window-2", isWindowScene: false, isForegroundActive: false)
        ]

        XCTAssertNil(select(scenes))
    }
}
