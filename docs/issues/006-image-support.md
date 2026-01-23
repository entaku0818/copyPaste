# 画像・ファイルサポート実装

**優先度**: 中
**ステータス**: 未着手
**ラベル**: enhancement, feature

## 概要

テキストだけでなく、画像やファイルもクリップボード履歴として保存できるようにする。

## 背景・目的

Yoinkの完全な機能パリティを実現：
- スクリーンショットの自動保存
- 画像のコピー&ペースト
- ファイルの一時保管
- より幅広いユースケースに対応

## 機能要件

### サポートする形式

**画像**
- [ ] PNG
- [ ] JPEG
- [ ] GIF（アニメーション含む）
- [ ] HEIC（iOSネイティブ形式）
- [ ] WebP

**その他**
- [ ] PDF
- [ ] URL（リンクプレビュー）
- [ ] リッチテキスト（HTML）

### UI/UX
- [ ] サムネイル表示
- [ ] 画像プレビュー（タップで全画面）
- [ ] ファイルサイズ表示
- [ ] 形式アイコン表示
- [ ] フィルタ機能（テキストのみ/画像のみ）

### データ管理
- [ ] ローカルストレージに保存
- [ ] キャッシュ管理（古い画像の自動削除）
- [ ] 最大ストレージサイズの制限
- [ ] 圧縮オプション

## 技術的な実装

### 1. データモデルの拡張

```swift
// ClipboardItem.swift
import Foundation
import UIKit

enum ClipboardItemType: String, Codable {
    case text
    case image
    case url
    case file
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let type: ClipboardItemType

    // テキスト
    var textContent: String?

    // 画像
    var imageData: Data?
    var imageThumbnailData: Data?

    // URL
    var url: URL?

    // ファイル
    var fileName: String?
    var fileSize: Int64?
    var fileURL: URL?

    // 共通
    var sizeInBytes: Int64 {
        if let imageData = imageData {
            return Int64(imageData.count)
        } else if let textContent = textContent {
            return Int64(textContent.utf8.count)
        }
        return fileSize ?? 0
    }

    // サムネイル画像
    var thumbnail: UIImage? {
        guard let data = imageThumbnailData ?? imageData else { return nil }
        return UIImage(data: data)
    }
}
```

### 2. クリップボード監視の拡張

```swift
// ClipboardHistoryFeature.swift
case .checkClipboard:
    guard state.isAppActive || state.isPiPActive else { return .none }

    let currentChangeCount = UIPasteboard.general.changeCount
    let lastChangeCount = state.lastChangeCount
    guard currentChangeCount != lastChangeCount else { return .none }

    Self.logger.info("Change detected! Count: \(currentChangeCount)")
    state.lastChangeCount = currentChangeCount

    // テキスト
    if let content = UIPasteboard.general.string {
        let item = ClipboardItem(
            id: UUID(),
            timestamp: Date(),
            type: .text,
            textContent: content
        )
        return .send(.addItem(item))
    }

    // 画像
    if let image = UIPasteboard.general.image {
        return .run { send in
            let item = await createImageItem(from: image)
            await send(.addItem(item))
        }
    }

    // URL
    if let url = UIPasteboard.general.url {
        let item = ClipboardItem(
            id: UUID(),
            timestamp: Date(),
            type: .url,
            url: url
        )
        return .send(.addItem(item))
    }

    return .none

func createImageItem(from image: UIImage) async -> ClipboardItem {
    // サムネイル生成（200x200）
    let thumbnailSize = CGSize(width: 200, height: 200)
    let thumbnail = await image.byPreparingThumbnail(ofSize: thumbnailSize)

    // PNG圧縮
    let imageData = image.pngData()
    let thumbnailData = thumbnail?.pngData()

    return ClipboardItem(
        id: UUID(),
        timestamp: Date(),
        type: .image,
        imageData: imageData,
        imageThumbnailData: thumbnailData
    )
}
```

### 3. UI実装

```swift
// ClipboardItemRow.swift
struct ClipboardItemRow: View {
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 12) {
            // サムネイル/アイコン
            itemIcon

            // コンテンツ
            VStack(alignment: .leading, spacing: 4) {
                itemContent

                HStack {
                    Text(item.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if item.sizeInBytes > 0 {
                        Text("・")
                            .foregroundColor(.secondary)
                        Text(ByteCountFormatter.string(
                            fromByteCount: item.sizeInBytes,
                            countStyle: .file
                        ))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var itemIcon: some View {
        switch item.type {
        case .text:
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)

        case .image:
            if let thumbnail = item.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.green)
                    .frame(width: 50, height: 50)
            }

        case .url:
            Image(systemName: "link")
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 50, height: 50)

        case .file:
            Image(systemName: "doc")
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 50, height: 50)
        }
    }

    @ViewBuilder
    private var itemContent: some View {
        switch item.type {
        case .text:
            Text(item.textContent ?? "")
                .lineLimit(2)

        case .image:
            Text("画像")
                .font(.headline)

        case .url:
            Text(item.url?.absoluteString ?? "")
                .lineLimit(1)
                .font(.caption)

        case .file:
            Text(item.fileName ?? "ファイル")
                .font(.headline)
        }
    }
}
```

### 4. 画像プレビュー

```swift
// ImagePreviewView.swift
struct ImagePreviewView: View {
    let item: ClipboardItem
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                if let imageData = item.imageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .navigationTitle("画像プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: /* ... */) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
```

### 5. ストレージ管理

```swift
// StorageManager.swift
import Foundation
import OSLog

class StorageManager {
    static let shared = StorageManager()
    private let logger = Logger(subsystem: "com.copyPaste", category: "Storage")

    private let maxStorageSize: Int64 = 100 * 1024 * 1024 // 100MB

    func checkAndCleanupIfNeeded(items: [ClipboardItem]) {
        let totalSize = items.reduce(0) { $0 + $1.sizeInBytes }

        if totalSize > maxStorageSize {
            logger.warning("Storage limit exceeded: \(totalSize) bytes")
            // 古い画像から削除
            // ...
        }
    }

    func compressImage(_ image: UIImage, quality: CGFloat = 0.7) -> Data? {
        return image.jpegData(compressionQuality: quality)
    }
}
```

## 技術的な考慮事項

### メモリ管理
- 大きな画像の効率的な読み込み
- サムネイルの生成とキャッシュ
- メモリ警告時の処理

### ストレージ
- ファイルシステムでの保存（Documentsディレクトリ）
- UserDefaultsではなくFileManagerを使用
- 定期的なクリーンアップ

### パフォーマンス
- 非同期での画像処理
- レイジーローディング
- バックグラウンドスレッドでの圧縮

### セキュリティ
- 機密画像の扱い
- スクリーンショットの自動削除オプション

## UI/UX

### フィルタ機能
```swift
enum ClipboardFilter {
    case all
    case text
    case images
    case urls
}

Section {
    Picker("フィルタ", selection: $filter) {
        Text("すべて").tag(ClipboardFilter.all)
        Text("テキスト").tag(ClipboardFilter.text)
        Text("画像").tag(ClipboardFilter.images)
        Text("URL").tag(ClipboardFilter.urls)
    }
    .pickerStyle(.segmented)
}
```

## テスト項目

- [ ] 画像のコピー＆保存
- [ ] スクリーンショットの自動保存
- [ ] サムネイル生成
- [ ] 画像プレビュー
- [ ] URLのコピー＆保存
- [ ] ファイルサイズ表示
- [ ] フィルタ機能
- [ ] ストレージ上限の動作
- [ ] メモリ警告時の動作
- [ ] 大きな画像の処理
- [ ] 複数画像の連続コピー

## 参考資料

- [Apple Developer - UIPasteboard](https://developer.apple.com/documentation/uikit/uipasteboard)
- [Working with Images](https://developer.apple.com/documentation/uikit/uiimage)
- [File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/Introduction/Introduction.html)

## 依存関係

- なし（独立して実装可能）

## 推定工数

- データモデル拡張: 0.5日
- クリップボード監視拡張: 1日
- UI実装（リスト表示）: 1日
- 画像プレビュー: 0.5日
- ストレージ管理: 1日
- テスト: 1日
- 合計: 5日
