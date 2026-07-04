import Foundation

/// 定型文（スニペット）。本体アプリで登録し、キーボード拡張から1タップで貼り付ける
struct Snippet: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var sortOrder: Int64
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String,
        sortOrder: Int64 = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 一覧・キーボードカードに表示する名前（タイトル未入力時は本文の先頭で代用）
    var displayTitle: String {
        title.isEmpty ? String(content.prefix(20)) : title
    }
}
