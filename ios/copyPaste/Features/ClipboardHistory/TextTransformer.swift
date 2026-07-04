import Foundation

/// 履歴アイテムのテキストに適用できる変換
/// 基本変換（大文字/小文字・改行除去・空白トリム）は無料、高度な変換はPro
enum TextTransform: String, CaseIterable, Equatable {
    case uppercase
    case lowercase
    case removeLineBreaks
    case trimWhitespace
    case snakeCase
    case camelCase
    case fullWidth
    case halfWidth
    case removeMarkdown
    case urlEncode
    case urlDecode

    /// Pro限定の変換かどうか
    var requiresPro: Bool {
        switch self {
        case .uppercase, .lowercase, .removeLineBreaks, .trimWhitespace:
            return false
        case .snakeCase, .camelCase, .fullWidth, .halfWidth, .removeMarkdown, .urlEncode, .urlDecode:
            return true
        }
    }

    // defaultValue はローカライズテーブルを持たないキーボード拡張向けのフォールバック
    var displayName: String {
        switch self {
        case .uppercase:
            return String(localized: "transform.uppercase", defaultValue: "大文字に変換")
        case .lowercase:
            return String(localized: "transform.lowercase", defaultValue: "小文字に変換")
        case .removeLineBreaks:
            return String(localized: "transform.removeLineBreaks", defaultValue: "改行を除去")
        case .trimWhitespace:
            return String(localized: "transform.trimWhitespace", defaultValue: "前後の空白を除去")
        case .snakeCase:
            return String(localized: "transform.snakeCase", defaultValue: "snake_caseに変換")
        case .camelCase:
            return String(localized: "transform.camelCase", defaultValue: "camelCaseに変換")
        case .fullWidth:
            return String(localized: "transform.fullWidth", defaultValue: "全角に変換")
        case .halfWidth:
            return String(localized: "transform.halfWidth", defaultValue: "半角に変換")
        case .removeMarkdown:
            return String(localized: "transform.removeMarkdown", defaultValue: "Markdownを除去")
        case .urlEncode:
            return String(localized: "transform.urlEncode", defaultValue: "URLエンコード")
        case .urlDecode:
            return String(localized: "transform.urlDecode", defaultValue: "URLデコード")
        }
    }

    var systemImageName: String {
        switch self {
        case .uppercase: return "textformat.size.larger"
        case .lowercase: return "textformat.size.smaller"
        case .removeLineBreaks: return "arrow.turn.down.left"
        case .trimWhitespace: return "scissors"
        case .snakeCase: return "underline"
        case .camelCase: return "textformat"
        case .fullWidth: return "arrow.left.and.right"
        case .halfWidth: return "arrow.right.and.line.vertical.and.arrow.left"
        case .removeMarkdown: return "doc.plaintext"
        case .urlEncode: return "percent"
        case .urlDecode: return "link"
        }
    }

    /// 変換を適用する
    func apply(to text: String) -> String {
        switch self {
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        case .removeLineBreaks:
            return text.components(separatedBy: .newlines).joined()
        case .trimWhitespace:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .snakeCase:
            return Self.toSnakeCase(text)
        case .camelCase:
            return Self.toCamelCase(text)
        case .fullWidth:
            return text.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? text
        case .halfWidth:
            return text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        case .removeMarkdown:
            return Self.strippingMarkdown(text)
        case .urlEncode:
            return text.addingPercentEncoding(withAllowedCharacters: Self.urlUnreservedCharacters) ?? text
        case .urlDecode:
            return text.removingPercentEncoding ?? text
        }
    }

    // MARK: - Helpers

    // RFC 3986 の unreserved 文字のみ許可（それ以外はすべてパーセントエンコード）
    private static let urlUnreservedCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    private static func toSnakeCase(_ text: String) -> String {
        var result = text
        // 連続大文字の境界（HTTPServer -> HTTP_Server）
        result = result.replacingOccurrences(
            of: "([A-Z]+)([A-Z][a-z])",
            with: "$1_$2",
            options: .regularExpression
        )
        // 小文字/数字と大文字の境界（helloWorld -> hello_World）
        result = result.replacingOccurrences(
            of: "([a-z0-9])([A-Z])",
            with: "$1_$2",
            options: .regularExpression
        )
        // 空白・ハイフンをアンダースコアに
        result = result.replacingOccurrences(
            of: "[\\s-]+",
            with: "_",
            options: .regularExpression
        )
        return result.lowercased()
    }

    private static func toCamelCase(_ text: String) -> String {
        let separators = CharacterSet(charactersIn: " _-\t\n\r")
        let parts = text.components(separatedBy: separators).filter { !$0.isEmpty }
        guard let first = parts.first else { return text }
        let head = first.prefix(1).lowercased() + first.dropFirst()
        let tail = parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return head + tail.joined()
    }

    private static func strippingMarkdown(_ text: String) -> String {
        var result = text
        let replacements: [(pattern: String, template: String)] = [
            // コードフェンス（```swift など）
            ("(?m)^```[^\n]*$\n?", ""),
            // 水平線 --- / ***
            ("(?m)^(-{3,}|\\*{3,})$\n?", ""),
            // 画像 ![alt](url) -> alt
            ("!\\[([^\\]]*)\\]\\(([^)]*)\\)", "$1"),
            // リンク [text](url) -> text
            ("\\[([^\\]]+)\\]\\(([^)]*)\\)", "$1"),
            // 強調 **bold** / *italic* / __bold__ / _italic_
            ("(\\*{1,3})(.+?)\\1", "$2"),
            ("(_{1,3})(.+?)\\1", "$2"),
            // インラインコード `code`
            ("`([^`]*)`", "$1"),
            // 見出し # Title
            ("(?m)^#{1,6}\\s+", ""),
            // 引用 > quote
            ("(?m)^>\\s?", ""),
            // 箇条書き - item / * item / + item
            ("(?m)^\\s*[-*+]\\s+", ""),
            // 番号付きリスト 1. item
            ("(?m)^\\s*\\d+\\.\\s+", "")
        ]
        for replacement in replacements {
            result = result.replacingOccurrences(
                of: replacement.pattern,
                with: replacement.template,
                options: .regularExpression
            )
        }
        return result
    }
}
