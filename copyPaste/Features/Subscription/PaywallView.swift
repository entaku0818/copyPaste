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

                        Text("Clipboard Pro")
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
                            icon: "infinity",
                            title: "無制限履歴",
                            description: "20件の制限なし",
                            color: .blue
                        )

                        FeatureRow(
                            icon: "magnifyingglass",
                            title: "高度な検索",
                            description: "すべての履歴を瞬時に検索",
                            color: .purple
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
                            icon: "wand.and.stars",
                            title: "テキスト変換",
                            description: "大文字・小文字・スネークケース等",
                            color: .pink
                        )
                    }
                    .padding(.horizontal)

                    // プラン選択
                    if let offering = revenueCat.offerings?.current {
                        VStack(spacing: 12) {
                            ForEach(offering.availablePackages) { package in
                                PackageButton(
                                    package: package,
                                    isSelected: selectedPackage?.identifier == package.identifier,
                                    onTap: {
                                        selectedPackage = package
                                    }
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

                    // 注意事項
                    VStack(spacing: 8) {
                        Text("• 7日間の無料トライアル")
                        Text("• いつでもキャンセル可能")
                        Text("• 自動更新されます")
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
        }
        .task {
            if selectedPackage == nil,
               let package = revenueCat.offerings?.current?.availablePackages.first {
                selectedPackage = package
            }
        }
    }

    private func purchasePackage() async {
        guard let package = selectedPackage else { return }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            _ = try await revenueCat.purchase(package: package)
            dismiss()
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

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(packageTitle)
                            .font(.headline)

                        if package.packageType == .annual {
                            Text("20%お得")
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

                    if package.packageType == .annual {
                        Text("月額換算 ¥200")
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
}

#Preview {
    PaywallView()
}
