import SwiftUI
import RevenueCat

struct PaywallView: View {
    @StateObject private var revenueCat = RevenueCatManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var isRestoring = false
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
                            } else {
                                Text("今すぐ始める")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
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
                        Text("• 7日間の無料トライアル")
                        Text("• いつでもキャンセル可能")
                        Text("• 自動更新されます")

                        HStack(spacing: 16) {
                            Link("利用規約", destination: URL(string: "https://clipkit-entaku.web.app/terms.html")!)
                            Text("·")
                            Link("プライバシーポリシー", destination: URL(string: "https://clipkit-entaku.web.app/privacy-policy.html")!)
                        }
                        .padding(.top, 4)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

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
                Text(errorMessage ?? "不明なエラーが発生しました")
            }
            .alert("購入完了", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("ClipKit Proへようこそ！\nすべての機能が使えるようになりました。")
            }
        }
        .task {
            if revenueCat.offerings == nil {
                await revenueCat.fetchOfferings()
            }
            if selectedPackage == nil,
               let package = revenueCat.offerings?.current?.availablePackages.first {
                selectedPackage = package
            }
        }
        .onChange(of: revenueCat.offerings) { _, newOfferings in
            if selectedPackage == nil,
               let package = newOfferings?.current?.availablePackages.first {
                selectedPackage = package
            }
        }
    }

    private func discountLabel(for package: Package, monthlyPrice: Decimal?) -> String? {
        guard package.packageType == .annual, let monthly = monthlyPrice, monthly > 0 else { return nil }
        let annualMonthly = package.storeProduct.price / 12
        let discount = Int(((monthly - annualMonthly) / monthly * 100) as NSDecimalNumber)
        guard discount > 0 else { return nil }
        return "\(discount)%お得"
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
                errorMessage = "復元可能な購入が見つかりませんでした"
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
            return "月間プラン"
        case .annual:
            return "年間プラン"
        default:
            return package.storeProduct.localizedTitle
        }
    }

    private var monthlyEquivalentPrice: String? {
        let product = package.storeProduct
        let rawMonthly = product.price / 12 as NSDecimalNumber
        let rounded = NSDecimalNumber(value: rawMonthly.doubleValue.rounded())
        guard let price = product.priceFormatter?.string(from: rounded) else { return nil }
        return "約\(price)"
    }
}

#Preview {
    PaywallView()
}
