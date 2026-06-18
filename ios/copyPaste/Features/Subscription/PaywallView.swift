import SwiftUI
import RevenueCat

struct PaywallView: View {
    @StateObject private var revenueCat = RevenueCatManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var isLoadingOfferings = false
    @State private var offeringsLoadFailed = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("ClipKit Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("すべての機能を解放")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)

                    // 機能リスト
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "calendar",
                            title: "3ヶ月履歴",
                            description: "過去3ヶ月分の履歴を保存・閲覧",
                            color: .blue
                        )

                        FeatureRow(
                            icon: "star.fill",
                            title: "お気に入り機能",
                            description: "重要な項目をピン留め",
                            color: .yellow
                        )

                        FeatureRow(
                            icon: "app.badge",
                            title: "ホーム画面ウィジェット",
                            description: "3サイズのウィジェット",
                            color: .green
                        )

                        FeatureRow(
                            icon: "keyboard",
                            title: "キーボードエクステンション",
                            description: "どこからでもアクセス",
                            color: .orange
                        )

                        FeatureRow(
                            icon: "icloud",
                            title: "iCloud同期",
                            description: "複数デバイスで履歴を共有",
                            color: .cyan
                        )

                        FeatureRow(
                            icon: "square.and.arrow.up",
                            title: "履歴エクスポート",
                            description: "CSV / Markdown 形式で書き出し",
                            color: .indigo
                        )

                    }
                    .padding(.horizontal)

                    // プラン選択
                    if let offering = revenueCat.offerings?.current {
                        let monthlyPrice = offering.availablePackages
                            .first(where: { $0.packageType == .monthly })?.storeProduct.price
                        VStack(spacing: 12) {
                            ForEach(offering.availablePackages) { package in
                                PackageButton(
                                    package: package,
                                    isSelected: selectedPackage?.identifier == package.identifier,
                                    onTap: {
                                        selectedPackage = package
                                    },
                                    discountLabel: discountLabel(for: package, monthlyPrice: monthlyPrice)
                                )
                            }
                        }
                        .padding(.horizontal)
                    } else if isLoadingOfferings {
                        ProgressView("プランを読み込み中...")
                            .padding()
                    } else if offeringsLoadFailed {
                        VStack(spacing: 12) {
                            Text("プランの読み込みに失敗しました")
                                .foregroundColor(.secondary)
                            Button("再試行") {
                                Task { await loadOfferings() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                    }

                    // 購入ボタン
                    Button {
                        Task {
                            await purchasePackage()
                        }
                    } label: {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else if selectedPackage?.packageType == .lifetime {
                                Text("購入する")
                                    .fontWeight(.semibold)
                            } else if let trialText = selectedPackageTrialText {
                                Text("無料で試す（\(trialText)）")
                                    .fontWeight(.semibold)
                            } else {
                                Text("今すぐ始める")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: selectedPackage != nil ? [.blue, .purple] : [.gray, .gray],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                    }
                    .disabled(selectedPackage == nil || isPurchasing)
                    .padding(.horizontal)

                    // 復元ボタン
                    Button {
                        Task {
                            await restorePurchases()
                        }
                    } label: {
                        HStack {
                            if isRestoring {
                                ProgressView()
                            } else {
                                Text("購入を復元")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .disabled(isRestoring || isPurchasing)
                    .padding(.horizontal)

                    // 注意事項・リンク
                    VStack(spacing: 8) {
                        if selectedPackage?.packageType == .lifetime {
                            Text("• 一度の購入で永久に利用できます")
                            Text("• Apple IDアカウントに課金されます")
                        } else {
                            if let trialText = selectedPackageTrialText {
                                Text("• \(trialText)の無料トライアル")
                            }
                            if let periodText = selectedPackagePeriodText {
                                Text("• \(periodText)ごとに自動更新")
                            }
                            Text("• いつでもキャンセル可能")
                            Text("• Apple IDアカウントに課金されます")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    HStack(spacing: 20) {
                        Link("利用規約", destination: URL(string: "https://clipkit-entaku.web.app/terms.html")!)
                            .underline()
                        Text("·")
                        Link("プライバシーポリシー", destination: URL(string: "https://clipkit-entaku.web.app/privacy-policy.html")!)
                            .underline()
                    }
                    .font(.footnote)
                    .foregroundColor(.accentColor)
                    .padding(.top, 8)

                    Spacer(minLength: 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? NSLocalizedString("paywall.error.unknown", value: "不明なエラーが発生しました", comment: ""))
            }
            .alert("購入完了", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("ClipKit Proへようこそ！\nすべての機能が使えるようになりました。")
            }
        }
        .presentationDetents([.large])
        .task {
            await loadOfferings()
        }
        .onChange(of: revenueCat.offerings) { _, newOfferings in
            if selectedPackage == nil,
               let packages = newOfferings?.current?.availablePackages {
                selectedPackage = PackageSelector.defaultPackage(from: packages)
            }
        }
    }

    private var selectedPackageTrialText: String? {
        guard let intro = selectedPackage?.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        let p = intro.subscriptionPeriod
        switch p.unit {
        case .day:   return String(format: NSLocalizedString("paywall.trial.days", value: "%d日間", comment: ""), p.value)
        case .week:  return String(format: NSLocalizedString("paywall.trial.weeks", value: "%d週間", comment: ""), p.value)
        case .month: return String(format: NSLocalizedString("paywall.trial.months", value: "%dヶ月間", comment: ""), p.value)
        case .year:  return String(format: NSLocalizedString("paywall.trial.years", value: "%d年間", comment: ""), p.value)
        @unknown default: return nil
        }
    }

    private var selectedPackagePeriodText: String? {
        guard let period = selectedPackage?.storeProduct.subscriptionPeriod else { return nil }
        switch (period.unit, period.value) {
        case (.month, 1): return NSLocalizedString("paywall.period.oneMonth", value: "1ヶ月", comment: "")
        case (.year, 1):  return NSLocalizedString("paywall.period.oneYear", value: "1年", comment: "")
        default:
            switch period.unit {
            case .day:   return String(format: NSLocalizedString("paywall.period.days", value: "%d日", comment: ""), period.value)
            case .week:  return String(format: NSLocalizedString("paywall.period.weeks", value: "%d週", comment: ""), period.value)
            case .month: return String(format: NSLocalizedString("paywall.period.months", value: "%dヶ月", comment: ""), period.value)
            case .year:  return String(format: NSLocalizedString("paywall.period.years", value: "%d年", comment: ""), period.value)
            @unknown default: return nil
            }
        }
    }

    private func loadOfferings() async {
        if let current = revenueCat.offerings?.current {
            if selectedPackage == nil {
                selectedPackage = PackageSelector.defaultPackage(from: current.availablePackages)
            }
            return
        }
        isLoadingOfferings = true
        offeringsLoadFailed = false
        await revenueCat.fetchOfferings()
        isLoadingOfferings = false
        if let packages = revenueCat.offerings?.current?.availablePackages {
            selectedPackage = PackageSelector.defaultPackage(from: packages)
        } else {
            offeringsLoadFailed = true
        }
    }

    private func discountLabel(for package: Package, monthlyPrice: Decimal?) -> String? {
        guard package.packageType == .annual, let monthly = monthlyPrice, monthly > 0 else { return nil }
        let annualMonthly = package.storeProduct.price / 12
        let discount = Int(((monthly - annualMonthly) / monthly * 100) as NSDecimalNumber)
        guard discount > 0 else { return nil }
        return String(format: NSLocalizedString("paywall.discount.format", value: "%d%%お得", comment: ""), discount)
    }

    private func purchasePackage() async {
        guard let package = selectedPackage else { return }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            _ = try await revenueCat.purchase(package: package)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            let info = try await revenueCat.restorePurchases()
            if info.entitlements.active.isEmpty {
                errorMessage = NSLocalizedString("paywall.error.noRestorable", value: "復元可能な購入が見つかりませんでした", comment: "")
                showError = true
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

// MARK: - Package Button
struct PackageButton: View {
    let package: Package
    let isSelected: Bool
    let onTap: () -> Void
    var discountLabel: String? = nil

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(packageTitle)
                            .font(.headline)

                        if let label = discountLabel {
                            Text(label)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    Text(package.storeProduct.localizedPriceString)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(subscriptionPeriodText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let trial = introductoryOfferText {
                        Text(trial)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }

                    if package.packageType == .annual,
                       let monthlyPrice = monthlyEquivalentPrice {
                        Text("月額換算 \(monthlyPrice)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var packageTitle: String {
        switch package.packageType {
        case .monthly:
            return NSLocalizedString("paywall.package.monthly", value: "月間プラン", comment: "")
        case .annual:
            return NSLocalizedString("paywall.package.annual", value: "年間プラン", comment: "")
        case .lifetime:
            return NSLocalizedString("paywall.package.lifetime", value: "買い切りプラン", comment: "")
        default:
            return package.storeProduct.localizedTitle
        }
    }

    private var subscriptionPeriodText: String {
        if package.packageType == .lifetime {
            return NSLocalizedString("paywall.renewal.lifetime", value: "一度の購入で永久に利用可能", comment: "")
        }
        guard let period = package.storeProduct.subscriptionPeriod else { return "" }
        switch (period.unit, period.value) {
        case (.month, 1): return NSLocalizedString("paywall.renewal.monthly", value: "1ヶ月ごとに自動更新", comment: "")
        case (.year, 1):  return NSLocalizedString("paywall.renewal.annual", value: "1年ごとに自動更新", comment: "")
        default:
            switch period.unit {
            case .day:   return String(format: NSLocalizedString("paywall.renewal.days", value: "%d日ごとに自動更新", comment: ""), period.value)
            case .week:  return String(format: NSLocalizedString("paywall.renewal.weeks", value: "%d週ごとに自動更新", comment: ""), period.value)
            case .month: return String(format: NSLocalizedString("paywall.renewal.months", value: "%dヶ月ごとに自動更新", comment: ""), period.value)
            case .year:  return String(format: NSLocalizedString("paywall.renewal.years", value: "%d年ごとに自動更新", comment: ""), period.value)
            @unknown default: return ""
            }
        }
    }

    private var introductoryOfferText: String? {
        guard let intro = package.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        let p = intro.subscriptionPeriod
        switch p.unit {
        case .day:   return String(format: NSLocalizedString("paywall.intro.days", value: "%d日間無料トライアル", comment: ""), p.value)
        case .week:  return String(format: NSLocalizedString("paywall.intro.weeks", value: "%d週間無料トライアル", comment: ""), p.value)
        case .month: return String(format: NSLocalizedString("paywall.intro.months", value: "%dヶ月間無料トライアル", comment: ""), p.value)
        case .year:  return String(format: NSLocalizedString("paywall.intro.years", value: "%d年間無料トライアル", comment: ""), p.value)
        @unknown default: return NSLocalizedString("paywall.intro.freeTrial", value: "無料トライアル付き", comment: "")
        }
    }

    private var monthlyEquivalentPrice: String? {
        let product = package.storeProduct
        let rawMonthly = product.price / 12 as NSDecimalNumber
        let rounded = NSDecimalNumber(value: rawMonthly.doubleValue.rounded())
        guard let price = product.priceFormatter?.string(from: rounded) else { return nil }
        return String(format: NSLocalizedString("paywall.monthlyEquivalent", value: "約%@", comment: ""), price)
    }
}

#Preview {
    PaywallView()
}
