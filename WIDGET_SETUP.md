# Widget Extension セットアップガイド

このガイドに従って、クリップボード履歴ウィジェットをセットアップします。

## 📋 必要な作業

### 1. Widget Extension ターゲットを追加

1. **Xcodeでプロジェクトを開く**
   ```bash
   open copyPaste.xcodeproj
   ```

2. **新しいターゲットを追加**
   - プロジェクトナビゲーターでプロジェクトを選択
   - メニュー: `File` → `New` → `Target...`
   - `iOS` → `Widget Extension` を選択
   - `Next` をクリック

3. **ターゲット設定**
   - **Product Name**: `ClipboardWidget`
   - **Team**: 既存のチーム（4YZQY4C47E）を選択
   - **Bundle Identifier**: `com.entaku.copyPaste.ClipboardWidget`
   - **Include Configuration Intent**: チェックを外す
   - `Finish` をクリック

4. **既存ファイルを使用**
   - Xcodeが自動生成した `ClipboardWidget` フォルダ内のファイルを削除
   - プロジェクトナビゲーターで `ClipboardWidget` フォルダを右クリック → `Add Files to "copyPaste"...`
   - `copyPaste/Widget/ClipboardWidget.swift` を追加
   - ターゲットメンバーシップで `ClipboardWidget` にチェック

---

### 2. App Group を設定

#### Widget Extension（ClipboardWidget）の設定

1. **プロジェクトナビゲーターで `ClipboardWidget` ターゲットを選択**
2. **`Signing & Capabilities` タブを開く**
3. **`+ Capability` をクリック**
4. **`App Groups` を追加**
5. **既存のApp Groupを選択**
   - `group.com.entaku.copyPaste` にチェック

---

### 3. 共有ファイルをターゲットに追加

ウィジェットで使用する共有ファイルを追加します。

1. **プロジェクトナビゲーターで以下のファイルを選択**
   - `copyPaste/Features/ClipboardHistory/ClipboardItem.swift`
   - `copyPaste/Features/ClipboardHistory/ClipboardStorageManager.swift`
   - `copyPaste/Features/ClipboardHistory/SharedConstants.swift`

2. **各ファイルについて:**
   - ファイルインスペクター（右側パネル）を開く
   - `Target Membership` セクションで `ClipboardWidget` にもチェックを入れる

---

### 4. Info.plist の設定

Widget Extensionの `Info.plist` に以下を追加：

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
</dict>
```

---

### 5. ビルドとテスト

#### ビルド

1. **スキーマを選択**
   - Xcodeのスキーマセレクターで `ClipboardWidget` を選択
   - ターゲットデバイスを選択（シミュレーターまたは実機）

2. **ビルド**
   - `Product` → `Build` (⌘+B)
   - エラーがないことを確認

#### ウィジェットのテスト

1. **メインアプリをビルド & 実行**
   - スキーマを `copyPaste` に切り替え
   - `Product` → `Run` (⌘+R)
   - クリップボード履歴にいくつかアイテムを追加

2. **ウィジェットを追加**
   - ホーム画面で長押し
   - 左上の `+` ボタンをタップ
   - `Clipboard History` を検索
   - 希望するサイズを選択
   - `ウィジェットを追加` をタップ

3. **動作確認**
   - ウィジェットにクリップボード履歴が表示されることを確認
   - ウィジェットをタップしてアプリが開くことを確認
   - 5分後にウィジェットが自動更新されることを確認

---

## 🎨 ウィジェットのサイズ

### Small（小）
- 最新の1件を表示
- アイコン、コンテンツプレビュー、タイムスタンプ
- お気に入りマーク表示

### Medium（中）
- 最新の3件を表示
- 各アイテムのアイコンとプレビュー
- 合計件数表示

### Large（大）
- 最新の6件を表示
- より詳細な情報（文字数など）
- カラフルなアイコンデザイン

---

## ⚙️ 設定項目

### 更新頻度
- デフォルト: 5分ごと
- `ClipboardWidget.swift` の `getTimeline` で変更可能

### 表示件数
- Small: 1件
- Medium: 3件
- Large: 6件
- `.prefix()` の値を変更することで調整可能

---

## 🐛 トラブルシューティング

### ウィジェットにデータが表示されない

1. **App Groupの設定を確認**
   - メインアプリと Widget Extension で同じ App Group ID が設定されているか
   - App Group ID が `group.com.entaku.copyPaste` であるか

2. **共有ファイルの確認**
   - `ClipboardItem.swift`, `ClipboardStorageManager.swift`, `SharedConstants.swift`
   - 各ファイルの Target Membership で `ClipboardWidget` にチェック

3. **メインアプリでデータがあるか確認**
   - メインアプリを起動してクリップボード履歴にアイテムがあるか確認

### ビルドエラー

1. **WidgetKit フレームワークの確認**
   - `ClipboardWidget` ターゲットの `General` タブ
   - `Frameworks and Libraries` に `WidgetKit.framework` が追加されているか

2. **Deployment Target の確認**
   - iOS 17.0 以上に設定されているか

---

## 📝 次のステップ

ウィジェットが動作したら、以下の機能拡張を検討できます：

- [ ] ディープリンク（ウィジェットから特定のアイテムを開く）
- [ ] インタラクティブウィジェット（iOS 17+でウィジェットから直接コピー）
- [ ] 設定可能なウィジェット（表示件数、フィルター）
- [ ] ライブアクティビティ対応

---

## 🎉 完了

これで、ホーム画面からクリップボード履歴にアクセスできるウィジェットが完成です！
