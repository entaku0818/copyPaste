# 共有エクステンション実装

**優先度**: 高
**ステータス**: 未着手
**ラベル**: enhancement, feature

## 概要

他のアプリから直接テキストや画像をcopyPasteアプリに送れるようにする共有エクステンション（Share Extension）を実装する。

## 背景・目的

Yoinkの主要機能の一つである「共有から直接保存」機能を実装することで：
- アプリを開かずにクリップボード履歴に保存できる
- Safari、メモ、メッセージなど様々なアプリから直接テキストを保存
- ユーザビリティの大幅な向上
- Yoinkとの機能パリティを高める

## 機能要件

### 基本機能
- [ ] 共有シートに「copyPasteに保存」メニューを追加
- [ ] テキストの受け取りと保存
- [ ] 画像の受け取りと保存（将来対応）
- [ ] URLの受け取りと保存
- [ ] 保存成功のフィードバック表示

### UI要件
- [ ] シンプルな確認画面
- [ ] 保存中インジケーター
- [ ] 成功/失敗のトースト表示
- [ ] カテゴリ選択（オプション）

## 技術的な実装

### 1. Share Extension Targetの追加

```swift
// ShareViewController.swift
import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        handleSharedItem(itemProvider: itemProvider)
    }

    private func handleSharedItem(itemProvider: NSItemProvider) {
        // テキストの処理
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier) { [weak self] data, error in
                guard let text = data as? String else { return }
                self?.saveToClipboardHistory(text: text)
            }
        }

        // URLの処理
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, error in
                guard let url = data as? URL else { return }
                self?.saveToClipboardHistory(text: url.absoluteString)
            }
        }
    }

    private func saveToClipboardHistory(text: String) {
        // App Groupsを使ってメインアプリとデータを共有
        let sharedDefaults = UserDefaults(suiteName: "group.com.copyPaste")
        var history = sharedDefaults?.stringArray(forKey: "clipboardHistory") ?? []

        let item = "\(Date().ISO8601Format()): \(text)"
        history.insert(item, at: 0)

        if history.count > 100 {
            history.removeLast()
        }

        sharedDefaults?.set(history, forKey: "clipboardHistory")

        // 完了
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
```

### 2. App Groupsの設定

**Info.plist設定**
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsText</key>
            <true/>
            <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
</dict>
```

**Entitlements設定**
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.copyPaste</string>
</array>
```

### 3. データ共有の実装

**メインアプリでの読み込み**
```swift
// ClipboardHistoryFeature.swift
func loadSharedData() {
    let sharedDefaults = UserDefaults(suiteName: "group.com.copyPaste")
    if let sharedHistory = sharedDefaults?.stringArray(forKey: "clipboardHistory") {
        // 共有データをメインの履歴にマージ
        // ...
    }
}
```

## 技術的な考慮事項

### App Groups
- メインアプリとエクステンション間でデータを共有するために必要
- Xcode の Signing & Capabilities で設定
- 同じApp Group IDを両方に設定する必要がある

### データの同期
- エクステンションで保存したデータをメインアプリで読み込む
- 重複を避けるためのIDまたはタイムスタンプ管理
- UserDefaultsまたはCoreDataでの共有

### メモリ制限
- Share Extensionはメモリ制限が厳しい（約30MB）
- 大きな画像や動画の処理には注意が必要
- バックグラウンドでの処理を考慮

### UI/UX
- できるだけシンプルに、素早く完了させる
- ユーザーを待たせない
- 失敗時の適切なエラーハンドリング

## テスト項目

- [ ] Safari からテキストを共有
- [ ] メモアプリからテキストを共有
- [ ] メッセージアプリからテキストを共有
- [ ] URLを共有
- [ ] 長いテキストの共有
- [ ] 特殊文字を含むテキストの共有
- [ ] メインアプリでの表示確認
- [ ] 重複排除の確認
- [ ] メモリ使用量の確認

## 参考資料

- [Apple Developer - App Extensions](https://developer.apple.com/app-extensions/)
- [Apple Developer - Share Extension](https://developer.apple.com/documentation/uikit/share_extensions)
- [App Groups Tutorial](https://www.raywenderlich.com/5419-ios-app-extensions-tutorial-app-groups)
- [Yoink - Share Extension example](https://apps.apple.com/jp/app/yoink-improved-drag-and-drop/id1260915283)

## 依存関係

- なし（独立して実装可能）

## 推定工数

- 実装: 1-2日
- テスト: 0.5日
- 合計: 1.5-2.5日
