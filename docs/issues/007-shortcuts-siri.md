# ショートカット/Siri対応実装

**優先度**: 中
**ステータス**: 未着手
**ラベル**: enhancement, feature, shortcuts

## 概要

iOS ショートカットアプリとSiriに対応し、音声やショートカットでクリップボード操作ができるようにする。

## 背景・目的

Yoinkの「ショートカット/Siri対応」機能を実装：
- 「Hey Siri、クリップボードを保存して」で音声保存
- ショートカットアプリで自動化
- より高度なワークフローの実現
- アクセシビリティの向上

## 機能要件

### Siri Shortcuts
- [ ] 「クリップボードを保存」アクション
- [ ] 「最新のクリップボードを取得」アクション
- [ ] 「クリップボード履歴を検索」アクション
- [ ] 「履歴をクリア」アクション

### カスタムインテント
- [ ] テキストをクリップボードに追加
- [ ] 履歴から特定のアイテムを取得
- [ ] 履歴件数を取得
- [ ] フィルタリング（日付、タイプ）

### Siri音声操作
- [ ] カスタムフレーズの登録
- [ ] 音声フィードバック
- [ ] エラーハンドリング

## 技術的な実装

### 1. App Intents実装（iOS 16+）

```swift
// SaveClipboardIntent.swift
import AppIntents

struct SaveClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "クリップボードを保存"
    static var description = IntentDescription("現在のクリップボードの内容を履歴に保存します")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // クリップボードの内容を取得
        guard let clipboardString = UIPasteboard.general.string else {
            return .result(dialog: "クリップボードが空です")
        }

        // 保存
        let sharedDefaults = UserDefaults(suiteName: "group.com.copyPaste")
        var history = sharedDefaults?.stringArray(forKey: "clipboardHistory") ?? []

        let item = "\(Date().ISO8601Format()): \(clipboardString)"
        history.insert(item, at: 0)

        if history.count > 100 {
            history.removeLast()
        }

        sharedDefaults?.set(history, forKey: "clipboardHistory")

        let preview = String(clipboardString.prefix(50))
        return .result(dialog: "「\(preview)」を保存しました")
    }
}
```

### 2. 履歴取得インテント

```swift
// GetLatestClipboardIntent.swift
import AppIntents

struct GetLatestClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "最新のクリップボードを取得"
    static var description = IntentDescription("クリップボード履歴から最新のアイテムを取得します")

    @Parameter(title: "件数", default: 1)
    var count: Int

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let sharedDefaults = UserDefaults(suiteName: "group.com.copyPaste")
        let history = sharedDefaults?.stringArray(forKey: "clipboardHistory") ?? []

        let items = Array(history.prefix(count))

        return .result(value: items)
    }
}
```

### 3. 検索インテント

```swift
// SearchClipboardIntent.swift
import AppIntents

struct SearchClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "クリップボード履歴を検索"
    static var description = IntentDescription("キーワードでクリップボード履歴を検索します")

    @Parameter(title: "検索キーワード")
    var keyword: String

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let sharedDefaults = UserDefaults(suiteName: "group.com.copyPaste")
        let history = sharedDefaults?.stringArray(forKey: "clipboardHistory") ?? []

        let results = history.filter { item in
            item.localizedCaseInsensitiveContains(keyword)
        }

        return .result(value: results)
    }
}
```

### 4. App Shortcuts（iOS 16+）

```swift
// AppShortcuts.swift
import AppIntents

struct CopyPasteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveClipboardIntent(),
            phrases: [
                "クリップボードを\(.applicationName)に保存",
                "\(.applicationName)でクリップボードを保存",
                "コピーした内容を\(.applicationName)に保存"
            ],
            shortTitle: "クリップボードを保存",
            systemImageName: "doc.on.clipboard"
        )

        AppShortcut(
            intent: GetLatestClipboardIntent(),
            phrases: [
                "\(.applicationName)から最新のクリップボードを取得",
                "最近コピーした内容を\(.applicationName)から取得"
            ],
            shortTitle: "最新を取得",
            systemImageName: "clock"
        )

        AppShortcut(
            intent: SearchClipboardIntent(),
            phrases: [
                "\(.applicationName)でクリップボードを検索"
            ],
            shortTitle: "履歴を検索",
            systemImageName: "magnifyingglass"
        )
    }
}
```

### 5. Legacy Intents（iOS 15以前）

```swift
// SaveClipboardIntentHandler.swift
import Intents

class SaveClipboardIntentHandler: NSObject, SaveClipboardIntentHandling {
    func handle(intent: SaveClipboardIntent, completion: @escaping (SaveClipboardIntentResponse) -> Void) {
        guard let clipboardString = UIPasteboard.general.string else {
            completion(SaveClipboardIntentResponse(code: .failure, userActivity: nil))
            return
        }

        // 保存処理
        let sharedDefaults = UserDefaults(suiteName: "group.com.copyPaste")
        var history = sharedDefaults?.stringArray(forKey: "clipboardHistory") ?? []

        let item = "\(Date().ISO8601Format()): \(clipboardString)"
        history.insert(item, at: 0)

        if history.count > 100 {
            history.removeLast()
        }

        sharedDefaults?.set(history, forKey: "clipboardHistory")

        let response = SaveClipboardIntentResponse(code: .success, userActivity: nil)
        response.savedContent = String(clipboardString.prefix(50))

        completion(response)
    }
}
```

### 6. Sirikit Intentの定義

**Intents.intentdefinition**
```
- SaveClipboard
  - Category: Save
  - Title: クリップボードを保存
  - Description: 現在のクリップボードの内容を保存します
  - Suggested Invocation Phrase: "クリップボードを保存"
  - Response:
    - savedContent (String)

- GetLatestClipboard
  - Category: Information
  - Title: 最新のクリップボードを取得
  - Parameters:
    - count (Integer, default: 1)
  - Response:
    - items (Array of String)
```

## 技術的な考慮事項

### App Groups
- Intentsからメインアプリのデータにアクセスするために必須
- 共有エクステンションと同じApp Groupを使用

### バックグラウンド実行
- Intentsはバックグラウンドで実行される
- メインアプリを起動せずに動作
- 高速な応答が求められる

### Siriの音声フィードバック
- 簡潔で分かりやすい応答
- 長すぎない（30秒以内）
- エラーメッセージも明確に

### プライバシー
- Siriの履歴に機密情報が残る可能性
- プライバシーポリシーに記載
- ユーザーに注意を促す

## UI/UX

### ショートカット追加ボタン

```swift
// ClipboardHistoryView.swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
            Button {
                // ショートカット追加画面を表示
                INVoiceShortcutCenter.shared.present(from: self)
            } label: {
                Label("Siriショートカットを追加", systemImage: "waveform.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
```

### 設定画面

```swift
Section("ショートカット") {
    NavigationLink {
        ShortcutsSettingsView()
    } label: {
        Label("Siriショートカットを管理", systemImage: "waveform.circle")
    }

    Toggle("ショートカット実行時に通知", isOn: $showNotifications)
}
```

## ショートカット例

### 自動保存ショートカット
```
トリガー: クリップボードが変更されたとき
アクション:
  1. クリップボードの内容を取得
  2. copyPasteに保存
  3. 通知を表示
```

### 定期クリーンアップ
```
トリガー: 毎日午前0時
アクション:
  1. copyPasteの履歴を取得
  2. 30日以上前のアイテムを削除
```

### テキスト変換パイプライン
```
トリガー: 手動
アクション:
  1. copyPasteから最新のテキストを取得
  2. テキストを大文字に変換
  3. 結果をcopyPasteに保存
```

## テスト項目

- [ ] Siriで「クリップボードを保存」
- [ ] Siriで「最新のクリップボードを取得」
- [ ] ショートカットアプリからの実行
- [ ] バックグラウンドでの動作
- [ ] App Groupsでのデータ共有
- [ ] エラー時の音声フィードバック
- [ ] 複数のショートカットの連続実行
- [ ] Siri音声認識の精度
- [ ] iOS 15とiOS 16の互換性

## 参考資料

- [Apple Developer - App Intents](https://developer.apple.com/documentation/appintents)
- [Apple Developer - SiriKit](https://developer.apple.com/documentation/sirikit)
- [Shortcuts User Guide](https://support.apple.com/guide/shortcuts/welcome/ios)
- [WWDC 2022 - App Intents](https://developer.apple.com/videos/play/wwdc2022/10032/)

## 依存関係

- App Groups設定（共有エクステンションと共通）

## 推定工数

- App Intents実装: 1.5日
- Legacy Intents実装: 1日
- App Shortcuts設定: 0.5日
- UI実装: 0.5日
- テスト: 0.5日
- 合計: 4日
