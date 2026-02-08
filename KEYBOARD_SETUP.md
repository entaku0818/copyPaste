# カスタムキーボード拡張機能 セットアップガイド

このガイドに従って、クリップボード履歴を表示するカスタムキーボードをセットアップします。

## 📋 必要な作業

### 1. Keyboard Extension ターゲットを追加

1. **Xcodeでプロジェクトを開く**
   ```
   open copyPaste.xcodeproj
   ```

2. **新しいターゲットを追加**
   - プロジェクトナビゲーターでプロジェクトを選択
   - メニュー: `File` → `New` → `Target...`
   - `iOS` → `Keyboard Extension` を選択
   - `Next` をクリック

3. **ターゲット設定**
   - **Product Name**: `ClipboardKeyboard`
   - **Team**: 既存のチーム（4YZQY4C47E）を選択
   - **Bundle Identifier**: `com.entaku.copyPaste.ClipboardKeyboard`
   - **Language**: Swift
   - `Finish` をクリック

4. **既存ファイルを使用**
   - Xcodeが自動生成した `ClipboardKeyboard` フォルダ内のファイルを削除
   - プロジェクトナビゲーターで `ClipboardKeyboard` フォルダを右クリック → `Add Files to "copyPaste"...`
   - 以下のファイルを追加:
     - `ClipboardKeyboard/KeyboardViewController.swift`
     - `ClipboardKeyboard/Info.plist`
   - ターゲットメンバーシップで `ClipboardKeyboard` にチェック

---

### 2. App Group を設定

App Groupを使用して、メインアプリとキーボード拡張でデータを共有します。

#### メインアプリ（copyPaste）の設定

1. **プロジェクトナビゲーターで `copyPaste` ターゲットを選択**
2. **`Signing & Capabilities` タブを開く**
3. **`+ Capability` をクリック**
4. **`App Groups` を追加**
5. **`+` ボタンをクリックして新しいApp Groupを追加**
   - App Group ID: `group.com.entaku.copyPaste`
   - チェックボックスにチェックを入れる

#### キーボード拡張（ClipboardKeyboard）の設定

1. **プロジェクトナビゲーターで `ClipboardKeyboard` ターゲットを選択**
2. **`Signing & Capabilities` タブを開く**
3. **`+ Capability` をクリック**
4. **`App Groups` を追加**
5. **既存のApp Groupを選択**
   - `group.com.entaku.copyPaste` にチェック

---

### 3. 共有ファイルをターゲットに追加

キーボード拡張で使用する共有ファイルを追加します。

1. **プロジェクトナビゲーターで以下のファイルを選択**
   - `copyPaste/Features/ClipboardHistory/ClipboardItem.swift`
   - `copyPaste/Features/ClipboardHistory/ClipboardStorageManager.swift`
   - `copyPaste/Features/ClipboardHistory/SharedConstants.swift`

2. **各ファイルについて:**
   - ファイルインスペクター（右側パネル）を開く
   - `Target Membership` セクションで `ClipboardKeyboard` にもチェックを入れる

---

### 4. ビルドとテスト

#### ビルド

1. **スキーマを選択**
   - Xcodeのスキーマセレクターで `ClipboardKeyboard` を選択
   - ターゲットデバイスを選択（シミュレーターまたは実機）

2. **ビルド**
   - `Product` → `Build` (⌘+B)
   - エラーがないことを確認

#### デバイスへのインストール

1. **メインアプリをビルド & 実行**
   - スキーマを `copyPaste` に切り替え
   - `Product` → `Run` (⌘+R)
   - アプリが起動し、クリップボード履歴が保存されることを確認

2. **キーボードを有効化**
   - デバイスの `設定` アプリを開く
   - `一般` → `キーボード` → `キーボード`
   - `新しいキーボードを追加...`
   - `クリップボード履歴` を選択
   - **重要**: `フルアクセスを許可` をONにする
     - これにより、App Groupでデータを共有できます

3. **キーボードをテスト**
   - メモアプリやSafariなど、任意のアプリを開く
   - テキストフィールドをタップ
   - キーボード切り替えボタン（🌐）を長押し
   - `クリップボード履歴` を選択
   - 履歴が表示されることを確認

---

## 🎨 UI説明

キーボードは以下の構成になっています：

```
┌────────────────────────────────────┐
│ 📝 "Hello"  🔗 apple.com  🖼️ 画像  │ ← クリップボード履歴（横スクロール）
├────────────────────────────────────┤
│                              [🌐]  │ ← キーボード切り替えボタン
└────────────────────────────────────┘
```

### 機能

- **履歴表示**: 最新10件のクリップボード履歴を表示
- **タップで挿入**: 履歴をタップすると入力エリアに挿入
- **自動更新**: メインアプリで新しいアイテムがコピーされると自動的に反映
- **対応形式**:
  - ✅ テキスト（そのまま挿入）
  - ✅ URL（URL文字列を挿入）
  - 🖼️ 画像（サムネイル表示のみ、挿入不可）
  - 📄 ファイル（ファイル名を挿入）

---

## ⚠️ トラブルシューティング

### キーボードに履歴が表示されない

1. **App Groupの設定を確認**
   - 両方のターゲットで同じApp Group IDが設定されているか
   - App Group IDが `group.com.entaku.copyPaste` であるか

2. **フルアクセスを有効化**
   - 設定 → 一般 → キーボード → キーボード → クリップボード履歴
   - `フルアクセスを許可` がONになっているか

3. **メインアプリでデータがあるか確認**
   - メインアプリを起動
   - クリップボード履歴にアイテムがあるか確認

### ビルドエラー

1. **共有ファイルがターゲットに追加されているか確認**
   - `ClipboardItem.swift`, `ClipboardStorageManager.swift`, `SharedConstants.swift`
   - 各ファイルの Target Membership で `ClipboardKeyboard` にチェック

2. **App Group Capabilityが追加されているか確認**
   - 両方のターゲットで App Groups が追加されているか

---

## 📝 次のステップ

キーボードが動作したら、以下の機能を追加できます：

- [ ] 検索機能（履歴を検索）
- [ ] お気に入り機能（よく使う履歴をピン留め）
- [ ] カテゴリフィルター（テキスト/URL/画像）
- [ ] 履歴の削除機能（キーボードから直接削除）
- [ ] テーマのカスタマイズ

---

## 🎉 完了

これで、システム全体で使えるクリップボード履歴キーボードが完成です！
Safari、メール、メモなど、どのアプリからでもクリップボード履歴にアクセスできます。
