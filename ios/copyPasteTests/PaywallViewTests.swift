import XCTest
@testable import ClipKit

// MARK: - PaywallView 年額プラン自動選択ロジックのテスト
//
// PackageSelector.selectDefault(from:preferring:) をモック型で検証する。
// RevenueCat.Package は StoreProduct なしに生成できないため、
// 同じ選択アルゴリズムを汎用ジェネリック関数として切り出し、ここで直接テストする。

final class PaywallViewTests: XCTestCase {

    // MARK: - テスト用モック

    private struct MockPackage {
        let id: Int
        let isAnnual: Bool
    }

    // MARK: - 年額プラン優先選択

    func testSelectDefault_selectsAnnualPlan_whenMixed() {
        let packages = [
            MockPackage(id: 1, isAnnual: false),
            MockPackage(id: 2, isAnnual: true),
        ]
        let selected = PackageSelector.selectDefault(from: packages, preferring: \.isAnnual)
        XCTAssertEqual(selected?.id, 2, "月額・年額が混在する場合、年額プランが選ばれること")
    }

    func testSelectDefault_selectsAnnualPlan_whenAnnualIsFirst() {
        let packages = [
            MockPackage(id: 1, isAnnual: true),
            MockPackage(id: 2, isAnnual: false),
        ]
        let selected = PackageSelector.selectDefault(from: packages, preferring: \.isAnnual)
        XCTAssertEqual(selected?.id, 1, "年額プランがリスト先頭にある場合もそれが選ばれること")
    }

    func testSelectDefault_selectsAnnualPlan_whenMiddleOfList() {
        let packages = [
            MockPackage(id: 1, isAnnual: false),
            MockPackage(id: 2, isAnnual: true),
            MockPackage(id: 3, isAnnual: false),
        ]
        let selected = PackageSelector.selectDefault(from: packages, preferring: \.isAnnual)
        XCTAssertEqual(selected?.id, 2, "年額プランがリスト中間にある場合もそれが選ばれること")
    }

    // MARK: - 年額プランなし時のフォールバック

    func testSelectDefault_fallsBackToFirst_whenNoAnnualAvailable() {
        let packages = [
            MockPackage(id: 1, isAnnual: false),
            MockPackage(id: 2, isAnnual: false),
        ]
        let selected = PackageSelector.selectDefault(from: packages, preferring: \.isAnnual)
        XCTAssertEqual(selected?.id, 1, "年額プランがない場合、先頭のプランが選ばれること")
    }

    func testSelectDefault_fallsBackToFirst_whenOnlyOnePackageAndNotAnnual() {
        let packages = [MockPackage(id: 1, isAnnual: false)]
        let selected = PackageSelector.selectDefault(from: packages, preferring: \.isAnnual)
        XCTAssertEqual(selected?.id, 1, "1種類のみで年額でない場合、そのプランが選ばれること")
    }

    // MARK: - 空配列

    func testSelectDefault_returnsNil_whenPackagesEmpty() {
        let selected = PackageSelector.selectDefault(from: [MockPackage](), preferring: \.isAnnual)
        XCTAssertNil(selected, "プランが空の場合、nil が返ること")
    }

    // MARK: - 年額プランのみ

    func testSelectDefault_selectsAnnual_whenOnlyAnnualAvailable() {
        let packages = [MockPackage(id: 1, isAnnual: true)]
        let selected = PackageSelector.selectDefault(from: packages, preferring: \.isAnnual)
        XCTAssertEqual(selected?.id, 1, "年額プランのみの場合、それが選ばれること")
    }
}
