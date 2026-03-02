---
name: clipkit-release-checklist
description: Step-by-step release checklist for ClipKit iOS app submission to TestFlight and App Store. Use when preparing release, uploading to TestFlight, submitting to App Store, bumping version, or creating a release.
metadata:
  author: ClipKit Team
  version: 1.0.0
  category: deployment
  tags: [release, fastlane, app-store, testflight, ios]
---

# ClipKit Release Checklist

**IMPORTANT FOR CLAUDE**: このスキルを使う際は、すべてのコマンドを **自動で実行** すること。ユーザーに「手動でやってください」と言ってはいけない。各ステップのコマンドは Claude が Bash ツールで直接叩く。確認が必要な場合は AskUserQuestion を使う。

## Project Info

- **Scheme**: `copyPaste`
- **Project**: `copyPaste.xcodeproj`
- **Bundle ID**: `com.entaku.clipkit`
- **App Name**: ClipKit - クリップボード管理
- **Team ID**: `4YZQY4C47E`
- **Metadata**: `fastlane/metadata/ja/`

## Fastlane Lanes

| Lane | Command | Description |
|------|---------|-------------|
| `beta` | `fastlane beta` | ビルド番号を自動インクリメントしてTestFlightへアップロード |
| `release` | `fastlane release` | App Storeへメタデータ・スクショ付きで申請 |

---

## Workflow A: TestFlight アップロード

```
TestFlight Progress:
- [ ] Step 1: リリースノート更新（任意）
- [ ] Step 2: コミット
- [ ] Step 3: fastlane beta 実行
- [ ] Step 4: TestFlight で確認
```

### Step 1: リリースノート更新（任意）

`fastlane/metadata/ja/release_notes.txt` を更新する。

**Format:**
```
バージョン 1.x.x

【新機能】
・新機能の説明

【改善】
・改善点

【修正】
・バグ修正
```

### Step 2: コミット

```bash
git add .
git commit -m "chore: prepare for TestFlight release

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Step 3: fastlane beta 実行

`fastlane beta` は自動的に:
1. ビルド番号 (`CURRENT_PROJECT_VERSION`) をインクリメント
2. `copyPaste` スキームでビルド・アーカイブ
3. TestFlight へアップロード

```bash
fastlane beta
```

### Step 4: TestFlight で確認

App Store Connect → TestFlight → ClipKit でビルドが届いているか確認。

---

## Workflow B: App Store 申請

```
App Store Release Progress:
- [ ] Step 1: バージョン番号アップ
- [ ] Step 2: リリースノート更新
- [ ] Step 3: コミット & タグ
- [ ] Step 4: fastlane beta でビルドをアップロード（審査用）
- [ ] Step 5: fastlane release でメタデータ申請
- [ ] Step 5.1: App Store Connect 手動設定（必要な場合）
- [ ] Step 6: GitHub Release 作成
```

### Step 1: バージョン番号アップ

```bash
# 現在のバージョン確認
grep "MARKETING_VERSION" copyPaste.xcodeproj/project.pbxproj | head -1

# バージョンアップ (例: 1.0 → 1.1)
sed -i '' 's/MARKETING_VERSION = 1.0;/MARKETING_VERSION = 1.1;/g' copyPaste.xcodeproj/project.pbxproj
```

### Step 2: リリースノート更新

`fastlane/metadata/ja/release_notes.txt` を編集する。

### Step 3: コミット & タグ

```bash
git add copyPaste.xcodeproj/project.pbxproj fastlane/metadata/
git commit -m "chore: bump version to 1.x

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

git tag v1.x
git push origin main
git push origin v1.x
```

### Step 4: TestFlight へビルドをアップロード

```bash
fastlane beta
```

Apple のビルド処理に数分かかる。処理完了後に次のステップへ。

### Step 5: fastlane release で申請

```bash
fastlane release
```

これで実行されること:
- メタデータ (`fastlane/metadata/`) のアップロード
- スクリーンショット (`fastlane/screenshots/`) のアップロード
- 審査に提出 (`submit_for_review: true`)

**⚠️ 申請が "missing required attribute" で失敗した場合は Step 5.1 へ。**

### Step 5.1: App Store Connect 手動設定

1. https://appstoreconnect.apple.com を開く
2. **マイApp** → **ClipKit** → 対象バージョン → **App情報**
3. 必須属性を設定:
   - **advertising**: はい/いいえ（AdMob使用の場合はいいえ）
   - **userGeneratedContent**: いいえ
4. **審査に提出** をクリック

### Step 6: GitHub Release 作成

```bash
gh release create v1.x --title "v1.x" --latest --notes "## 変更内容
- タブ分け実装など"
```

---

## 現在のバージョン確認コマンド

```bash
# マーケティングバージョン
grep "MARKETING_VERSION" copyPaste.xcodeproj/project.pbxproj | head -1

# ビルド番号
grep "CURRENT_PROJECT_VERSION" copyPaste.xcodeproj/project.pbxproj | head -1
```

---

## トラブルシューティング

### fastlane beta が失敗する

```bash
# 依存関係を確認
bundle install

# ビルドをクリーン
xcodebuild clean -scheme copyPaste -project copyPaste.xcodeproj
```

### "build could not be added" エラー

Apple のビルド処理中。数分後に再実行する。

```bash
fastlane release
```

### API Key エラー

環境変数を確認:
```bash
echo $APP_STORE_CONNECT_API_KEY_KEY_ID
echo $APP_STORE_CONNECT_API_KEY_ISSUER_ID
```

### git tag が既に存在する

```bash
git tag -d v1.x
git push origin :refs/tags/v1.x
git tag v1.x && git push origin v1.x
```

---

## スクリーンショット情報

- **保存先**: `fastlane/screenshots/ja-JP/`
- **サイズ**: 1320x2868 (iPhone 16 Pro Max)
- **6枚**: `1_clipboard_history`, `2_keyboard`, `3_pip_monitoring`, `4_settings`, `5_image_preview`, `6_keyboard_setup`
