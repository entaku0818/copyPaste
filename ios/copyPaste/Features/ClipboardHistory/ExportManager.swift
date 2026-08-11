import Foundation

enum ExportFormat {
    case csv
    case markdown
}

enum ExportManager {

    /// 履歴を書き出して一時ファイルのURLを返す。書き込みに失敗したらnilを返す。
    ///
    /// 以前は `try?` で書き込みエラーを握り潰して常に非nilのURLを返していたため、
    /// 呼び出し元が存在しないファイルでShareSheetを開いてしまっていた（issue #72）。
    ///
    /// 文字列の構築とファイルI/Oを含むため、メインスレッドを塞がないよう
    /// 呼び出し側から非同期に呼ぶ（issue #79）。
    static func export(_ items: [ClipboardItem], format: ExportFormat) -> URL? {
        let (content, fileName): (String, String)
        switch format {
        case .csv:
            content = csvString(from: items)
            fileName = "clipkit_export.csv"
        case .markdown:
            content = markdownString(from: items)
            fileName = "clipkit_export.md"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return nil
        }
        return url
    }

    /// 共有が終わったエクスポートファイルを削除する（issue #80）。
    ///
    /// 履歴にはパスワードや個人情報が含まれうるため、共有後に平文のまま
    /// 一時ディレクトリへ残置しない。
    static func cleanUp(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - CSV

    private static func csvString(from items: [ClipboardItem]) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = ["timestamp,type,category,favorite,content"]
        for item in items {
            let ts = formatter.string(from: item.timestamp)
            let type = item.type.rawValue
            let cat = item.category?.rawValue ?? ""
            let fav = item.isFavorite ? "1" : "0"
            let escaped = item.content.replacingOccurrences(of: "\"", with: "\"\"")
            lines.append("\(ts),\(type),\(cat),\(fav),\"\(escaped)\"")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Markdown

    private static func markdownString(from items: [ClipboardItem]) -> String {
        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .medium
        dateFmt.timeStyle = .none

        let timeFmt = DateFormatter()
        timeFmt.dateStyle = .none
        timeFmt.timeStyle = .short

        var lines = ["# ClipKit Export", ""]
        let calendar = Calendar.current
        var currentDay: Date?

        for item in items {
            let day = calendar.startOfDay(for: item.timestamp)
            if currentDay != day {
                currentDay = day
                lines.append("## \(dateFmt.string(from: day))")
                lines.append("")
            }

            let time = timeFmt.string(from: item.timestamp)
            let cat = item.category.map { "[\($0.rawValue.uppercased())] " } ?? ""
            let star = item.isFavorite ? "⭐ " : ""
            let firstLine = item.content.components(separatedBy: "\n").first ?? ""
            let preview = firstLine.count > 80 ? String(firstLine.prefix(80)) + "…" : firstLine
            lines.append("- \(star)\(cat)\(preview) _(\(time))_")
        }
        return lines.joined(separator: "\n")
    }
}
