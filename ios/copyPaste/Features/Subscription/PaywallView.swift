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
                    VStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(ClipKitColor.brandGradient)
                                .frame(width: 72, height: 72)
                                .shadow(color: ClipKitColor.indigoLight.opacity(0.5), radius: 24)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 32))
                                .foregroundColor(ClipKitColor.crown)
                        }

                        Text("ClipKit Pro")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(ClipKitColor.textOnDark)

                        Text(NSLocalizedString("paywall.subtitle", value: "すべての機能を解放", comment: ""))
                            .font(.system(size: 14))
                            .foregroundColor(ClipKitColor.textOnDarkSecondary)
                    }
                    .padding(.top, 20)

                    // 機能リスト
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "calendar",
                            title: NSLocalizedString("paywall.feature.history.title", value: "履歴を無制限に保存", comment: ""),
                            description: NSLocalizedString("paywall.feature.history.description", value: "無料版は直近3日・20件まで", comment: ""),
                            color: ClipKitColor.indigoLight
                        )

                        FeatureRow(
                            icon: "star.fill",
                            title: NSLocalizedString("paywall.feature.favorites.title", value: "お気に入り機能", comment: ""),
                            description: NSLocalizedString("paywall.feature.favorites.description", value: "重要な項目をピン留め", comment: ""),
                            color: ClipKitColor.favorite
                        )

                        FeatureRow(
                            icon: "app.badge",
                            title: NSLocalizedString("paywall.feature.widget.title", value: "ホーム画面ウィジェット", comment: ""),
                            description: NSLocalizedString("paywall.feature.widget.description", value: "3サイズのウィジェット", comment: ""),
                            color: ClipKitColor.success
                        )

                        FeatureRow(
                            icon: "keyboard",
                            title: NSLocalizedString("paywall.feature.keyboard.title", value: "キーボードフル表示", comment: ""),
                            description: NSLocalizedString("paywall.feature.keyboard.description", value: "キーボードに履歴10件を表示（無料版は3件）", comment: ""),
                            color: Color(hex: 0x6F9BFF)
                        )

                        FeatureRow(
                            icon: "icloud",
                            title: NSLocalizedString("paywall.feature.icloud.title", value: "iCloud同期", comment: ""),
                            description: NSLocalizedString("paywall.feature.icloud.description", value: "複数デバイスで履歴を共有", comment: ""),
                            color: Color(hex: 0x3AA3FF)
                        )

                        FeatureRow(
                            icon: "square.and.arrow.up",
                            title: NSLocalizedString("paywall.feature.export.title", value: "履歴エクスポート", comment: ""),
                            description: NSLocalizedString("paywall.feature.export.description", value: "CSV / Markdown 形式で書き出し", comment: ""),
                            color: Color(hex: 0x4FD0C8)
                        )

                        FeatureRow(
                            icon: "wand.and.stars",
                            title: NSLocalizedString("paywall.feature.transform.title", value: "高度なテキスト変換", comment: ""),
                            description: NSLocalizedString("paywall.feature.transform.description", value: "ケース変換・全角半角・URLエンコード等", comment: ""),
                            color: ClipKitColor.badgePurple.foreground
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
                        ProgressView(NSLocalizedString("paywall.loadingPlans", value: "プランを読み込み中...", comment: ""))
                            .padding()
                    } else if offeringsLoadFailed {
                        VStack(spacing: 12) {
                            Text(NSLocalizedString("paywall.loadFailed", value: "プランの読み込みに失敗しました", comment: ""))
                                .foregroundColor(.secondary)
                            Button(NSLocalizedString("paywall.retry", value: "再試行", comment: "")) {
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
                                Text(NSLocalizedString("paywall.purchase", value: "購入する", comment: ""))
                                    .fontWeight(.semibold)
                            } else if let trialText = selectedPackageTrialText {
                                Text(String(format: NSLocalizedString("paywall.tryFree", value: "無料で試す（%@）", comment: ""), trialText))
                                    .fontWeight(.semibold)
                            } else {
                                Text(NSLocalizedString("paywall.startNow", value: "今すぐ始める", comment: ""))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            selectedPackage != nil
                                ? ClipKitColor.brandGradient
                                : LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: ClipKitRadius.control, style: .continuous))
                        .shadow(color: selectedPackage != nil ? ClipKitColor.indigo.opacity(0.45) : .clear, radius: 16, y: 8)
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
                                Text(NSLocalizedString("paywall.restore", value: "購入を復元", comment: ""))
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
                            Text(NSLocalizedString("paywall.note.lifetime", value: "• 一度の購入で永久に利用できます", comment: ""))
                            Text(NSLocalizedString("paywall.note.billedToAppleID", value: "• Apple IDアカウントに課金されます", comment: ""))
                        } else {
                            if let trialText = selectedPackageTrialText {
                                Text(String(format: NSLocalizedString("paywall.note.trial", value: "• %@の無料トライアル", comment: ""), trialText))
                            }
                            if let periodText = selectedPackagePeriodText {
                                Text(String(format: NSLocalizedString("paywall.note.autoRenew", value: "• %@ごとに自動更新", comment: ""), periodText))
                            }
                            Text(NSLocalizedString("paywall.note.cancelAnytime", value: "• いつでもキャンセル可能", comment: ""))
                            Text(NSLocalizedString("paywall.note.billedToAppleID", value: "• Apple IDアカウントに課金されます", comment: ""))
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    HStack(spacing: 20) {
                        Link(NSLocalizedString("paywall.terms", value: "利用規約", comment: ""), destination: URL(string: "https://clipkit-entaku.web.app/terms.html")!)
                            .underline()
                        Text("·")
                        Link(NSLocalizedString("paywall.privacyPolicy", value: "プライバシーポリシー", comment: ""), destination: URL(string: "https://clipkit-entaku.web.app/privacy-policy.html")!)
                            .underline()
                    }
                    .font(.footnote)
                    .foregroundColor(ClipKitColor.accentOnDark)
                    .padding(.top, 8)

                    Spacer(minLength: 32)
                }
            }
            .background(ClipKitColor.darkSurface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("paywall.close", value: "閉じる", comment: "")) {
                        dismiss()
                    }
                    .tint(ClipKitColor.accentOnDark)
                }
            }
            .preferredColorScheme(.dark)
            .alert(NSLocalizedString("paywall.errorTitle", value: "エラー", comment: ""), isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? NSLocalizedString("paywall.error.unknown", value: "不明なエラーが発生しました", comment: ""))
            }
            .alert(NSLocalizedString("paywall.successTitle", value: "購入完了", comment: ""), isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(NSLocalizedString("paywall.successMessage", value: "ClipKit Proへようこそ！\nすべての機能が使えるようになりました。", comment: ""))
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
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.16))
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(ClipKitColor.textOnDark)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(ClipKitColor.textOnDarkSecondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(ClipKitColor.indigoLight)
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
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundColor(ClipKitColor.textOnDark)

                        if let label = discountLabel {
                            Text(label)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(ClipKitColor.darkSurface)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(ClipKitColor.crown)
                                .clipShape(Capsule())
                        }
                    }

                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(ClipKitColor.textOnDark)

                    Text(subscriptionPeriodText)
                        .font(.caption)
                        .foregroundColor(ClipKitColor.textOnDarkSecondary)

                    if let trial = introductoryOfferText {
                        Text(trial)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ClipKitColor.success)
                    }

                    if package.packageType == .annual,
                       let monthlyPrice = monthlyEquivalentPrice {
                        Text(String(format: NSLocalizedString("paywall.monthlyEquivalentLabel", value: "月額換算 %@", comment: ""), monthlyPrice))
                            .font(.caption)
                            .foregroundColor(ClipKitColor.textOnDarkSecondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? ClipKitColor.indigoLight : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: ClipKitRadius.control, style: .continuous)
                    .fill(isSelected ? ClipKitColor.indigoLight.opacity(0.12) : Color.clear)
            )
            .background(
                RoundedRectangle(cornerRadius: ClipKitRadius.control, style: .continuous)
                    .strokeBorder(isSelected ? ClipKitColor.indigoLight : Color.white.opacity(0.18), lineWidth: isSelected ? 2 : 1.5)
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
