# 今日ウィジェット（ホーム画面ウィジェット）実装

**優先度**: 高
**ステータス**: 未着手
**ラベル**: enhancement, feature, widget

## 概要

ホーム画面やロック画面からクリップボードの内容を直接保存できるウィジェットを実装する。

## 背景・目的

Yoinkの「クリップボードバー」機能を参考に：
- アプリを開かずにクリップボードを保存
- ワンタップで現在のクリップボード内容を履歴に追加
- ホーム画面からのアクセスでユーザビリティ向上
- 最近の履歴をウィジェットで確認可能

## 機能要件

### ウィジェットの種類

**1. クリップボード保存ウィジェット（小）**
- [ ] 「保存」ボタン1つのシンプルなウィジェット
- [ ] タップで現在のクリップボードを保存
- [ ] 保存成功のフィードバック

**2. 履歴表示ウィジェット（中）**
- [ ] 最新3件の履歴を表示
- [ ] タップでアプリを開く
- [ ] 保存ボタンも含む

**3. 履歴＋プレビューウィジェット（大）**
- [ ] 最新5件の履歴を表示
- [ ] 各アイテムのプレビュー
- [ ] 保存ボタン
- [ ] タップでアプリの該当アイテムへ

### ロック画面ウィジェット（iOS 16+）
- [ ] 円形の保存ボタン
- [ ] インライン表示（最新の履歴件数）
- [ ] 長方形ウィジェット（最新1件のプレビュー）

## 技術的な実装

### 1. Widget Extension Targetの追加

```swift
// ClipboardWidget.swift
import WidgetKit
import SwiftUI

struct ClipboardWidget: Widget {
    let kind: String = "ClipboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClipboardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("クリップボード保存")
        .description("ワンタップで現在のクリップボードを保存")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), clipboardItems: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), clipboardItems: loadRecentItems())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, clipboardItems: loadRecentItems())

        // 15分ごとに更新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }

    private func loadRecentItems() -> [String] {
        let sharedDefaults = UserDefaults(suiteName: "group.com.copyPaste")
        return sharedDefaults?.stringArray(forKey: "clipboardHistory")?.prefix(5).map { $0 } ?? []
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let clipboardItems: [String]
}
```

### 2. ウィジェットUI実装

```swift
// ClipboardWidgetEntryView.swift
struct ClipboardWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            EmptyView()
        }
    }
}

struct SmallWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Color.blue

            VStack {
                Image(systemName: "doc.on.clipboard")
                    .font(.largeTitle)
                    .foregroundColor(.white)

                Text("クリップボードを保存")
                    .font(.caption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .widgetURL(URL(string: "copypaste://save-clipboard"))
    }
}

struct MediumWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最近のコピー")
                    .font(.headline)
                Spacer()
                Button(intent: SaveClipboardIntent()) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }

            ForEach(entry.clipboardItems.prefix(3), id: \.self) { item in
                Text(item)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if entry.clipboardItems.isEmpty {
                Text("履歴がありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
```

### 3. App Intentsの実装（iOS 16+）

```swift
// SaveClipboardIntent.swift
import AppIntents

struct SaveClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "クリップボードを保存"
    static var description = IntentDescription("現在のクリップボードの内容を保存します")

    func perform() async throws -> some IntentResult {
        // クリップボードの内容を取得
        guard let clipboardString = UIPasteboard.general.string else {
            return .result()
        }

        // App Groupsを使って保存
        let sharedDefaults = UserDefaults(suiteName: "group.com.copyPaste")
        var history = sharedDefaults?.stringArray(forKey: "clipboardHistory") ?? []

        let item = "\(Date().ISO8601Format()): \(clipboardString)"
        history.insert(item, at: 0)

        if history.count > 100 {
            history.removeLast()
        }

        sharedDefaults?.set(history, forKey: "clipboardHistory")

        // ウィジェットを更新
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
```

### 4. URL Schemeの処理

```swift
// copyPasteApp.swift
.onOpenURL { url in
    if url.scheme == "copypaste" {
        if url.host == "save-clipboard" {
            // クリップボードを保存
            // ...
        }
    }
}
```

## 技術的な考慮事項

### App Groups（必須）
- ウィジェットとメインアプリでデータ共有
- 共有エクステンションと同じApp Groupを使用

### タイムライン更新
- 15分ごとに自動更新
- メインアプリからの手動更新（`WidgetCenter.shared.reloadAllTimelines()`）
- バッテリー消費に配慮

### クリップボードアクセス
- ウィジェットからのクリップボードアクセスは制限される可能性
- App Intentsを使用する場合、ユーザーのアクション時のみ可能

### ロック画面ウィジェット
- iOS 16以降のみ
- より厳しいメモリ・パフォーマンス制限
- シンプルなUIが推奨される

## UI/UXデザイン

### カラースキーム
- ライトモード/ダークモード対応
- アプリのブランドカラーを使用
- システムカラーとの調和

### アニメーション
- 保存時のフィードバックアニメーション
- スムーズなトランジション

## テスト項目

- [ ] 小ウィジェットの表示
- [ ] 中ウィジェットの表示
- [ ] 大ウィジェットの表示
- [ ] ロック画面ウィジェットの表示（iOS 16+）
- [ ] 保存ボタンの動作
- [ ] 履歴の正しい表示
- [ ] ライトモード/ダークモード
- [ ] メインアプリとのデータ同期
- [ ] タイムライン更新
- [ ] メモリ使用量

## 参考資料

- [Apple Developer - WidgetKit](https://developer.apple.com/documentation/widgetkit)
- [Apple Developer - App Intents](https://developer.apple.com/documentation/appintents)
- [Creating a Widget Extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- [Lock Screen Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets#Lock-Screen-widgets)

## 依存関係

- App Groups設定（共有エクステンションと共通）
- iOS 16以降の機能を使用する場合は対応バージョンの確認

## 推定工数

- 基本ウィジェット実装: 1-2日
- App Intents実装: 0.5日
- ロック画面ウィジェット: 0.5日
- UI/UX調整: 0.5日
- テスト: 0.5日
- 合計: 3-4日
