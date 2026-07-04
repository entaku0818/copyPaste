import Foundation

/// スニペット本文の変数プレースホルダ（{日付} {時刻} 等）を貼り付け時点の値に展開する
enum SnippetVariableExpander {
    static func expand(
        _ text: String,
        date: Date = Date(),
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        guard text.contains("{") else { return text }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: date)

        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.timeZone = timeZone
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: date)

        let replacements: [String: String] = [
            "{日付}": dateString,
            "{時刻}": timeString,
            "{date}": dateString,
            "{time}": timeString
        ]
        var result = text
        for (placeholder, value) in replacements {
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        return result
    }
}
