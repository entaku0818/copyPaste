# サブスクリプション実装まとめ

RevenueCatを使用したサブスクリプションモデルの実装が完了しました。

## 📊 実装内容

### 機能分け

#### 無料版（Free）
- ✅ クリップボード自動監視（PiP）
- ✅ 履歴保存（最大20件）
- ✅ テキスト・URL・画像・ファイル対応
- ✅ 基本的なコピー＆ペースト
- ✅ スワイプで削除
- ✅ iCloud同期（20件まで）

#### Pro版（Subscription）
- ✅ すべての無料版機能
- ✅ 無制限履歴（最大100件）
- ✅ 高度な検索機能
- ✅ お気に入り/ピン機能
- ✅ ホーム画面ウィジェット（全サイズ）
- ✅ キーボードエクステンション
- ✅ テキスト変換（今後実装）

### 価格設定
- **月額**: ¥250
- **年額**: ¥2,400（月額換算 ¥200、20%オフ）
- **無料トライアル**: 7日間

## 🆕 追加されたファイル

### 1. RevenueCatManager.swift
- RevenueCatのSDK管理
- サブスクリプション状態の管理
- 購入・復元処理

### 2. PaywallView.swift
- サブスクリプション購入画面
- 機能比較表
- プラン選択UI

### 3. REVENUECAT_SETUP.md
- RevenueCat統合の詳細手順
- App Store Connect設定
- トラブルシューティング

## 🔧 修正されたファイル

### 1. ClipboardHistoryFeature.swift
- `isProUser`状態の追加
- `showPaywall`状態の追加
- `maxHistoryCount`プロパティ（無料版20件制限）
- Pro機能チェックロジック（検索、お気に入り）
- Paywallアクションの追加

### 2. ClipboardHistoryView.swift
- Pro状態バッジの表示
- Paywall画面の表示
- 検索バーの無効化（無料版）
- 履歴件数制限の表示

### 3. copyPasteApp.swift
- RevenueCatの初期化

### 4. README.md
- 機能リストの更新（無料版 vs Pro版）
- 価格プランの追加

## ✅ 次にやること

### 必須作業（実装完了前）

1. **RevenueCat SDKを追加**
   ```bash
   open copyPaste.xcodeproj
   ```
   - File → Add Package Dependencies...
   - URL: `https://github.com/RevenueCat/purchases-ios`
   - Target: `copyPaste` を選択

2. **RevenueCat アカウントを作成**
   - https://app.revenuecat.com でアカウント作成
   - プロジェクト作成: `Clipboard Pro`
   - Bundle ID: `com.entaku.copyPaste`

3. **API Keyを設定**
   - RevenueCat Dashboard → API Keys
   - Public API Keyをコピー
   - `RevenueCatManager.swift` 19行目に貼り付け
     ```swift
     Purchases.configure(withAPIKey: "appl_xxxxxxxxxxxxxxxxx")
     ```

4. **App Store Connect設定**
   - サブスクリプショングループ作成
   - 月間プラン（¥250）: `clipboard_pro_monthly`
   - 年間プラン（¥2,400）: `clipboard_pro_annual`
   - 無料トライアル: 7日間

5. **RevenueCat Dashboard設定**
   - Entitlement作成: `pro`
   - Products接続（monthly, annual）
   - Offering作成: `default`

### 推奨作業（実装後）

1. **サンドボックステスト**
   - テストユーザーでの購入テスト
   - 復元機能のテスト
   - Pro機能の動作確認

2. **ウィジェットにPro制限追加**
   - ウィジェットの表示をPro限定にする
   - 無料版では「Pro機能」の表示

3. **キーボードエクステンションにPro制限追加**
   - エクステンションの利用をPro限定にする

4. **アナリティクス設定**
   - RevenueCatのアナリティクスを確認
   - 購入率・解約率のモニタリング

5. **テストコード追加**
   - Pro機能のロジックをテスト
   - Paywall表示のテスト

## 📚 参考ドキュメント

- [REVENUECAT_SETUP.md](./REVENUECAT_SETUP.md) - 詳細セットアップ手順
- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)

## 🐛 既知の問題

- RevenueCat SDKがまだ追加されていないため、ビルドエラーが発生します
  - → 上記「必須作業」の手順1を実行してください

## 💡 ヒント

- **デバッグ時**: `RevenueCatManager.swift` 18行目の`Purchases.logLevel = .debug`のコメントを外すと詳細ログが表示されます
- **テスト時**: App Store Connectでサンドボックステスターを作成してください
- **本番前**: 必ず実機でサンドボックステストを行ってください

---

すべての設定が完了したら、アプリをビルドして動作確認を行ってください！
