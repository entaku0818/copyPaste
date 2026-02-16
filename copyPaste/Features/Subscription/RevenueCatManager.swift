import Foundation
import RevenueCat
import os.log

private let logger = Logger(subsystem: "com.entaku.copyPaste", category: "RevenueCat")

/// RevenueCatを使ったサブスクリプション管理
@MainActor
final class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()

    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?
    @Published private(set) var isProUser = false

    // Entitlement ID（App Store Connectで設定するEntitlement ID）
    private let proEntitlementID = "pro"

    private override init() {
        super.init()
    }

    /// RevenueCatの初期化
    func configure() {
        // TODO: RevenueCat DashboardからAPI Keyを取得して設定
        // Purchases.logLevel = .debug // デバッグ時のみ
        Purchases.configure(withAPIKey: "YOUR_REVENUECAT_API_KEY")

        // CustomerInfoの変更を監視
        Purchases.shared.delegate = self

        logger.info("RevenueCat configured")

        // 初回の状態取得
        Task {
            await fetchCustomerInfo()
            await fetchOfferings()
        }
    }

    /// ユーザー情報を取得
    func fetchCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            self.customerInfo = info
            let newProStatus = info.entitlements[proEntitlementID]?.isActive == true
            self.isProUser = newProStatus

            // Pro状態をApp Group UserDefaultsに保存（ウィジェット・キーボード用）
            SharedConstants.sharedDefaults?.set(newProStatus, forKey: SharedConstants.proStatusKey)

            logger.info("Customer info fetched. Pro status: \(self.isProUser)")
        } catch {
            logger.error("Failed to fetch customer info: \(error.localizedDescription)")
        }
    }

    /// 利用可能なサブスクリプションプランを取得
    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
            logger.info("Offerings fetched: \(offerings.all.count) offerings")
        } catch {
            logger.error("Failed to fetch offerings: \(error.localizedDescription)")
        }
    }

    /// サブスクリプション購入
    func purchase(package: Package) async throws -> CustomerInfo {
        do {
            let result = try await Purchases.shared.purchase(package: package)
            let info = result.customerInfo
            self.customerInfo = info
            let newProStatus = info.entitlements[proEntitlementID]?.isActive == true
            self.isProUser = newProStatus

            // Pro状態をApp Group UserDefaultsに保存
            SharedConstants.sharedDefaults?.set(newProStatus, forKey: SharedConstants.proStatusKey)

            logger.info("Purchase successful. Pro status: \(self.isProUser)")
            return info
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// サブスクリプションの復元
    func restorePurchases() async throws -> CustomerInfo {
        do {
            let info = try await Purchases.shared.restorePurchases()
            self.customerInfo = info
            let newProStatus = info.entitlements[proEntitlementID]?.isActive == true
            self.isProUser = newProStatus

            // Pro状態をApp Group UserDefaultsに保存
            SharedConstants.sharedDefaults?.set(newProStatus, forKey: SharedConstants.proStatusKey)

            logger.info("Purchases restored. Pro status: \(self.isProUser)")
            return info
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Pro機能にアクセス可能かチェック（nonisolated - UserDefaultsから読み取り）
    nonisolated func hasProAccess() -> Bool {
        return SharedConstants.sharedDefaults?.bool(forKey: SharedConstants.proStatusKey) ?? false
    }

    /// 無料版の履歴件数制限（nonisolated - UserDefaultsから読み取り）
    nonisolated var maxHistoryCount: Int {
        let isPro = SharedConstants.sharedDefaults?.bool(forKey: SharedConstants.proStatusKey) ?? false
        return isPro ? Int.max : 20
    }
}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            let newProStatus = customerInfo.entitlements[self.proEntitlementID]?.isActive == true
            self.isProUser = newProStatus

            // Pro状態をApp Group UserDefaultsに保存
            SharedConstants.sharedDefaults?.set(newProStatus, forKey: SharedConstants.proStatusKey)

            logger.info("Customer info updated. Pro status: \(self.isProUser)")
        }
    }
}
