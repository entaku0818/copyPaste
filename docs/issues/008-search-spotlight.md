# 検索機能とSpotlight統合実装

**優先度**: 低
**ステータス**: 未着手
**ラベル**: enhancement, feature, search

## 概要

アプリ内検索機能とiOS Spotlight検索への統合を実装し、クリップボード履歴を素早く見つけられるようにする。

## 背景・目的

Yoinkの「Spotlight検索」機能を参考に：
- 大量の履歴から素早く目的のアイテムを検索
- iOS標準のSpotlight検索からもアクセス可能
- ユーザビリティの大幅な向上
- パワーユーザー向けの高度な機能

## 機能要件

### アプリ内検索
- [ ] リアルタイム検索
- [ ] 全文検索
- [ ] 検索履歴
- [ ] 検索候補
- [ ] フィルタ（日付、タイプ）
- [ ] ハイライト表示

### Spotlight統合
- [ ] クリップボード履歴のインデックス化
- [ ] Spotlightからの検索
- [ ] クイックアクション
- [ ] プレビュー表示
- [ ] ディープリンク

## 技術的な実装

### 1. アプリ内検索UI

```swift
// SearchView.swift
import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [ClipboardItem] = []
    @State private var isSearching = false

    var body: some View {
        NavigationView {
            List {
                if searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(searchResults) { item in
                        ClipboardItemRow(item: item, searchText: searchText)
                    }
                }
            }
            .navigationTitle("検索")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "クリップボード履歴を検索"
            )
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }
        }
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        Task {
            // 非同期検索
            let results = await searchClipboardHistory(query: query)
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }

    private func searchClipboardHistory(query: String) async -> [ClipboardItem] {
        // UserDefaultsまたはCoreDataから検索
        let sharedDefaults = UserDefaults(suiteName: "group.com.copyPaste")
        guard let history = sharedDefaults?.stringArray(forKey: "clipboardHistory") else {
            return []
        }

        return history
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .compactMap { ClipboardItem.from(string: $0) }
    }
}
```

### 2. 検索結果のハイライト

```swift
// HighlightedText.swift
struct HighlightedText: View {
    let text: String
    let searchText: String

    var body: some View {
        let attributed = highlightedAttributedString()

        Text(AttributedString(attributed))
    }

    private func highlightedAttributedString() -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)

        guard !searchText.isEmpty else {
            return attributedString
        }

        let range = NSRange(location: 0, length: text.utf16.count)
        let regex = try? NSRegularExpression(
            pattern: NSRegularExpression.escapedPattern(for: searchText),
            options: .caseInsensitive
        )

        regex?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            attributedString.addAttribute(
                .backgroundColor,
                value: UIColor.yellow,
                range: matchRange
            )
        }

        return attributedString
    }
}
```

### 3. Spotlight統合

```swift
// SpotlightManager.swift
import CoreSpotlight
import MobileCoreServices
import OSLog

class SpotlightManager {
    static let shared = SpotlightManager()
    private let logger = Logger(subsystem: "com.copyPaste", category: "Spotlight")

    func indexItem(_ item: ClipboardItem) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

        // 基本情報
        attributeSet.title = item.textContent?.prefix(50).description ?? "クリップボードアイテム"
        attributeSet.contentDescription = item.textContent
        attributeSet.keywords = extractKeywords(from: item.textContent ?? "")

        // メタデータ
        attributeSet.contentCreationDate = item.timestamp
        attributeSet.contentModificationDate = item.timestamp

        // サムネイル（画像の場合）
        if let thumbnailData = item.imageThumbnailData {
            attributeSet.thumbnailData = thumbnailData
        }

        // 検索可能なアイテムを作成
        let searchableItem = CSSearchableItem(
            uniqueIdentifier: item.id.uuidString,
            domainIdentifier: "com.copyPaste.clipboard",
            attributeSet: attributeSet
        )

        // インデックスに追加
        CSSearchableIndex.default().indexSearchableItems([searchableItem]) { error in
            if let error = error {
                self.logger.error("Failed to index item: \(error.localizedDescription)")
            } else {
                self.logger.info("Successfully indexed item: \(item.id)")
            }
        }
    }

    func indexAllItems(_ items: [ClipboardItem]) {
        let searchableItems = items.compactMap { item -> CSSearchableItem? in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

            attributeSet.title = item.textContent?.prefix(50).description ?? "クリップボードアイテム"
            attributeSet.contentDescription = item.textContent
            attributeSet.contentCreationDate = item.timestamp

            return CSSearchableItem(
                uniqueIdentifier: item.id.uuidString,
                domainIdentifier: "com.copyPaste.clipboard",
                attributeSet: attributeSet
            )
        }

        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                self.logger.error("Failed to index items: \(error.localizedDescription)")
            } else {
                self.logger.info("Successfully indexed \(searchableItems.count) items")
            }
        }
    }

    func deleteItem(id: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id]) { error in
            if let error = error {
                self.logger.error("Failed to delete item: \(error.localizedDescription)")
            }
        }
    }

    func deleteAllItems() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.copyPaste.clipboard"]) { error in
            if let error = error {
                self.logger.error("Failed to delete all items: \(error.localizedDescription)")
            } else {
                self.logger.info("Successfully deleted all indexed items")
            }
        }
    }

    private func extractKeywords(from text: String) -> [String] {
        // 簡易的なキーワード抽出
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return Array(Set(words.filter { $0.count > 3 }))
    }
}
```

### 4. Spotlightからのディープリンク処理

```swift
// copyPasteApp.swift
.onContinueUserActivity(CSSearchableItemActionType) { userActivity in
    guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
        return
    }

    // アイテムIDからアイテムを取得して表示
    if let uuid = UUID(uuidString: identifier) {
        // アプリ内でそのアイテムに移動
        // ...
    }
}
```

### 5. TCA統合

```swift
// ClipboardHistoryFeature.swift
enum Action {
    // 既存のアクション
    // ...

    // 検索関連
    case searchTextChanged(String)
    case searchResultsReceived([ClipboardItem])
    case spotlightIndexItem(ClipboardItem)
    case spotlightDeleteItem(UUID)
}

case let .searchTextChanged(query):
    guard !query.isEmpty else {
        state.searchResults = []
        return .none
    }

    return .run { [items = state.items] send in
        let results = items.filter { item in
            item.textContent?.localizedCaseInsensitiveContains(query) ?? false
        }
        await send(.searchResultsReceived(results))
    }

case let .searchResultsReceived(results):
    state.searchResults = results
    return .none

case let .spotlightIndexItem(item):
    return .run { _ in
        SpotlightManager.shared.indexItem(item)
    }

case let .addItem(item):
    state.items.insert(item, at: 0)
    if state.items.count > state.maxItems {
        state.items.removeLast()
    }

    // Spotlightにインデックス
    return .send(.spotlightIndexItem(item))
```

## 技術的な考慮事項

### パフォーマンス
- 大量のアイテムの検索最適化
- インデックス構築の非同期処理
- キャッシュの活用

### Spotlightのクォータ
- インデックス可能なアイテム数に制限がある
- 古いアイテムは定期的に削除

### プライバシー
- 機密情報のインデックス化を避ける
- ユーザーが設定でSpotlight統合をOFF可能に

### バッテリー消費
- バックグラウンドでのインデックス更新
- 適切なタイミングでのバッチ処理

## UI/UX

### 検索バー
- ナビゲーションバーに統合
- リアルタイム検索候補
- 検索履歴の表示

### フィルタ
```swift
enum SearchFilter {
    case all
    case today
    case thisWeek
    case thisMonth
    case text
    case images
}
```

### 設定
```swift
Section("Spotlight検索") {
    Toggle("Spotlight検索を有効化", isOn: $enableSpotlight)

    if enableSpotlight {
        Text("クリップボード履歴をSpotlight検索に追加します。iOS標準の検索から履歴を検索できるようになります。")
            .font(.caption)
            .foregroundColor(.secondary)

        Button("今すぐインデックスを再構築") {
            rebuildSpotlightIndex()
        }
    }
}
```

## テスト項目

- [ ] アプリ内検索の動作
- [ ] リアルタイム検索
- [ ] ハイライト表示
- [ ] Spotlightインデックス作成
- [ ] Spotlightからの検索
- [ ] ディープリンクの動作
- [ ] 大量データでのパフォーマンス
- [ ] インデックス削除
- [ ] 設定のON/OFF
- [ ] バックグラウンド更新

## 参考資料

- [Apple Developer - Core Spotlight](https://developer.apple.com/documentation/corespotlight)
- [App Search Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/index.html)
- [Searchable modifier](https://developer.apple.com/documentation/swiftui/view/searchable(text:placement:prompt:))

## 依存関係

- なし（独立して実装可能）

## 推定工数

- アプリ内検索UI: 1日
- 検索ロジック: 0.5日
- Spotlight統合: 1.5日
- ディープリンク処理: 0.5日
- TCA統合: 0.5日
- テスト: 0.5日
- 合計: 4.5日
