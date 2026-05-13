import RevenueCat

/// 年額プラン優先の自動選択ロジック（PaywallView と onChange から共通利用）
enum PackageSelector {

    /// packages から年額プランを優先して選択。年額がなければ先頭、空なら nil。
    static func defaultPackage(from packages: [Package]) -> Package? {
        selectDefault(from: packages, preferring: { $0.packageType == .annual })
    }

    /// テスタブルな汎用選択ロジック: predicate を満たす最初の要素を返し、なければ先頭要素を返す。
    static func selectDefault<T>(from items: [T], preferring predicate: (T) -> Bool) -> T? {
        items.first(where: predicate) ?? items.first
    }
}
