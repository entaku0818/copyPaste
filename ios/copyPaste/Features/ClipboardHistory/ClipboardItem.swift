import Foundation
import UIKit

enum ClipboardItemType: String, Codable {
    case text
    case image
    case url
    case file
}

/// サムネイルのデコード結果をアイテムIDでキャッシュする（issue #70）。
///
/// `thumbnail` は計算プロパティなので、リストのセル再利用のたびに
/// `UIImage(data:)` でビットマップデコードが走り、スクロール時のフレーム落ちの
/// 原因になっていた。1アイテムの画像は変化しないためIDをキーにできる。
/// NSCacheはスレッドセーフで、メモリ圧迫時にOSが自動で破棄する。
private enum ThumbnailCache {
    private static let cache: NSCache<NSUUID, UIImage> = {
        let cache = NSCache<NSUUID, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    /// `data` はキャッシュヒット時に評価しないようautoclosureで受け取る
    static func image(for id: UUID, data: @autoclosure () -> Data?) -> UIImage? {
        let key = id as NSUUID
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = data(), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    var timestamp: Date
    let type: ClipboardItemType
    var isFavorite: Bool = false
    var deletedAt: Date? = nil

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

    // 分析結果
    var category: ItemCategory?
    var ocrText: String?

    // 後方互換性のため、contentプロパティを残す
    var content: String {
        switch type {
        case .text:
            return textContent ?? ""
        case .image:
            return "画像"
        case .url:
            return url?.absoluteString ?? ""
        case .file:
            return fileName ?? "ファイル"
        }
    }

    // サイズ計算
    var sizeInBytes: Int64 {
        if let imageData = imageData {
            return Int64(imageData.count)
        } else if let textContent = textContent {
            return Int64(textContent.utf8.count)
        }
        return fileSize ?? 0
    }

    // サムネイル画像取得（デコード結果はIDでキャッシュする）
    var thumbnail: UIImage? {
        ThumbnailCache.image(for: id, data: imageThumbnailData ?? imageData)
    }

    // テキスト用の便利なイニシャライザ（後方互換性）
    init(id: UUID = UUID(), content: String, timestamp: Date = Date(), isFavorite: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.type = .text
        self.textContent = content
        self.isFavorite = isFavorite
    }

    // 画像用イニシャライザ
    init(id: UUID = UUID(), image: UIImage, thumbnail: UIImage? = nil, timestamp: Date = Date(), isFavorite: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.type = .image
        self.imageData = image.pngData()
        self.imageThumbnailData = thumbnail?.pngData()
        self.isFavorite = isFavorite
    }

    // URL用イニシャライザ
    init(id: UUID = UUID(), url: URL, timestamp: Date = Date(), isFavorite: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.type = .url
        self.url = url
        self.isFavorite = isFavorite
    }

    // 完全なイニシャライザ（ストレージからの復元用）
    init(
        id: UUID,
        timestamp: Date,
        type: ClipboardItemType,
        isFavorite: Bool = false,
        textContent: String? = nil,
        imageData: Data? = nil,
        imageThumbnailData: Data? = nil,
        url: URL? = nil,
        fileName: String? = nil,
        fileSize: Int64? = nil,
        fileURL: URL? = nil,
        category: ItemCategory? = nil,
        ocrText: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.isFavorite = isFavorite
        self.textContent = textContent
        self.imageData = imageData
        self.imageThumbnailData = imageThumbnailData
        self.url = url
        self.fileName = fileName
        self.fileSize = fileSize
        self.fileURL = fileURL
        self.category = category
        self.ocrText = ocrText
    }

    // Codableの実装
    enum CodingKeys: String, CodingKey {
        case id, timestamp, type, isFavorite
        case textContent, imageData, imageThumbnailData
        case url, fileName, fileSize, fileURL
        case category, ocrText
    }
} 