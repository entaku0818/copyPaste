import Foundation
import RevenueCat
import os.log

private let logger = Logger(subsystem: "com.entaku.clipkit", category: "RevenueCat")

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
        Purchases.configure(withAPIKey: "appl_qEbMiTwZchIzFzsqHgQlUeqhvIK")

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
            saveProStatusToAppGroup(newProStatus)

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
            saveProStatusToAppGroup(newProStatus)

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
            saveProStatusToAppGroup(newProStatus)

            logger.info("Purchases restored. Pro status: \(self.isProUser)")
            return info
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Pro状態をApp Group UserDefaultsに書き込む
    /// synchronize()でディスクへの即時フラッシュを保証（キーボード拡張がcfprefsdをバイパスして直接読むため必要）
    private func saveProStatusToAppGroup(_ status: Bool) {
        guard let defaults = SharedConstants.sharedDefaults else {
            logger.error("App Group UserDefaults unavailable - sharedDefaults is nil")
            return
        }
        defaults.set(status, forKey: SharedConstants.proStatusKey)
        defaults.synchronize()
        logger.info("Pro status written to App Group: \(status)")
    }

    /// Pro機能にアクセス可能かチェック（nonisolated - UserDefaultsから読み取り）
    nonisolated func hasProAccess() -> Bool {
        return SharedConstants.sharedDefaults?.bool(forKey: SharedConstants.proStatusKey) ?? false
    }

    /// 履歴件数制限（Pro: 無制限）
    nonisolated var maxHistoryCount: Int {
        return Int.max
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
            saveProStatusToAppGroup(newProStatus)

            logger.info("Customer info updated. Pro status: \(self.isProUser)")
        }
    }
}
