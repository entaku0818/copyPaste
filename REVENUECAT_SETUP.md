# RevenueCat セットアップガイド

このガイドに従って、RevenueCatによるサブスクリプション機能をセットアップします。

## 📋 必要な作業

### 1. RevenueCat SDKを追加

1. **Xcodeでプロジェクトを開く**
   ```bash
   open copyPaste.xcodeproj
   ```

2. **Swift Package Managerでパッケージを追加**
   - メニュー: `File` → `Add Package Dependencies...`
   - URLを入力: `https://github.com/RevenueCat/purchases-ios`
   - `Dependency Rule`: `Up to Next Major Version` → `5.0.0`
   - `Add to Target`: `copyPaste` を選択
   - `Add Package` をクリック

3. **パッケージの選択**
   - `RevenueCat` を選択（✓をつける）
   - `Add Package` をクリック

---

### 2. RevenueCat Dashboard セットアップ

1. **アカウント作成**
   - https://app.revenuecat.com にアクセス
   - アカウントを作成（無料）

2. **プロジェクト作成**
   - `Create New Project` をクリック
   - Project Name: `Clipboard Pro`
   - プラットフォーム: `iOS`

3. **App情報を設定**
   - App Name: `copyPaste`
   - Bundle ID: `com.entaku.copyPaste`
   - App Store Connect からShared Secretを取得して入力
     - App Store Connect → App情報 → App Store Connect API → 共有シークレット

4. **API Keyを取得**
   - Dashboard → Project Settings → API Keys
   - iOS用の**Public API Key**をコピー
   - `copyPaste/Features/Subscription/RevenueCatManager.swift` の19行目に貼り付け
     ```swift
     Purchases.configure(withAPIKey: "YOUR_REVENUECAT_API_KEY")
     ```
     を
     ```swift
     Purchases.configure(withAPIKey: "appl_xxxxxxxxxxxxxxxxx")
     ```
     に変更

---

### 3. App Store Connect でサブスクリプション設定

1. **App Store Connect にログイン**
   - https://appstoreconnect.apple.com

2. **サブスクリプショングループを作成**
   - アプリを選択 → `サブスクリプション` タブ
   - `サブスクリプショングループを作成` をクリック
   - 参照名: `Clipboard Pro Subscription`

3. **サブスクリプションを作成（月間プラン）**
   - `+` ボタンをクリック
   - **Product ID**: `clipboard_pro_monthly`
   - **参照名**: `Clipboard Pro - Monthly`
   - **サブスクリプション期間**: `1ヶ月`
   - **価格**: `¥250`

4. **サブスクリプションを作成（年間プラン）**
   - `+` ボタンをクリック
   - **Product ID**: `clipboard_pro_annual`
   - **参照名**: `Clipboard Pro - Annual`
   - **サブスクリプション期間**: `1年`
   - **価格**: `¥2,400`

5. **無料トライアルを設定**
   - 各サブスクリプションの詳細画面で
   - `無料トライアル` を有効化
   - 期間: `7日間`

6. **サブスクリプション情報を入力**
   - ローカライズ情報を追加（日本語）
   - サブスクリプション表示名
   - 説明文

---

### 4. RevenueCat Dashboard でEntitlementを設定

1. **Entitlementを作成**
   - RevenueCat Dashboard → Entitlements
   - `Create Entitlement` をクリック
   - **Identifier**: `pro`（コード内の`proEntitlementID`と一致）
   - **Display Name**: `Pro Features`

2. **Productを接続**
   - Products タブ → `Add Product`
   - **Product ID**: `clipboard_pro_monthly`
   - **Product Type**: `Subscription`
   - **Entitlement**: `pro` を選択

   - もう一つ追加:
   - **Product ID**: `clipboard_pro_annual`
   - **Product Type**: `Subscription`
   - **Entitlement**: `pro` を選択

3. **Offeringを作成**
   - Offerings タブ → `Create Offering`
   - **Identifier**: `default`
   - **Description**: `Default Offering`
   - Packagesを追加:
     - Monthly: `clipboard_pro_monthly`
     - Annual: `clipboard_pro_annual`
   - `Make Current` をクリック（これをデフォルトOfferingにする）

---

### 5. アプリコードの初期化を追加

`copyPaste/copyPasteApp.swift` を編集して、RevenueCatを初期化します：

```swift
import SwiftUI
import ComposableArchitecture

@main
struct copyPasteApp: App {
    init() {
        // RevenueCatの初期化
        RevenueCatManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                store: Store(
                    initialState: ClipboardHistoryFeature.State()
                ) {
                    ClipboardHistoryFeature()
                }
            )
        }
    }
}
```

---

### 6. テスト

#### サンドボックステスト

1. **テストユーザーを作成**
   - App Store Connect → ユーザーとアクセス → Sandbox テスター
   - `+` ボタンでテストユーザーを作成

2. **デバイスでサインアウト**
   - 設定 → App Store → サインアウト

3. **アプリでテスト購入**
   - アプリを実行
   - Paywall画面を開く
   - プランを選択して購入
   - サンドボックステスターでログイン
   - 購入を確認

4. **確認項目**
   - 購入フローが正常に動作
   - Pro機能が解放される
   - RevenueCat Dashboardで購入が記録される

---

## 🐛 トラブルシューティング

### RevenueCat SDKがインポートできない

1. **パッケージの確認**
   - Xcodeのプロジェクトナビゲーター
   - `Package Dependencies` セクションで `purchases-ios` があるか確認

2. **ビルドをクリーン**
   - `Product` → `Clean Build Folder` (Shift+Cmd+K)
   - 再度ビルド

### 購入がRevenueCat Dashboardに表示されない

1. **API Keyを確認**
   - Public API Keyが正しく設定されているか
   - iOS用のKeyを使用しているか

2. **Product IDを確認**
   - App Store ConnectのProduct ID
   - RevenueCat DashboardのProduct ID
   - 両方が完全に一致しているか

### サブスクリプションが有効にならない

1. **Entitlement設定を確認**
   - RevenueCat Dashboard → Entitlements
   - ProductとEntitlementの紐付けが正しいか
   - Offeringが`Current`になっているか

2. **アプリを再起動**
   - 完全にアプリを終了
   - 再度起動してCustomerInfoを更新

---

## 📝 次のステップ

RevenueCatのセットアップが完了したら：

1. ✅ 機能ロックの実装（検索、お気に入り、ウィジェット等）
2. ✅ 無料版の履歴件数制限（20件）
3. ✅ Paywall表示の最適化
4. ✅ アナリティクスの設定

---

## 📚 参考リンク

- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [RevenueCat iOS SDK Guide](https://docs.revenuecat.com/docs/ios)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
