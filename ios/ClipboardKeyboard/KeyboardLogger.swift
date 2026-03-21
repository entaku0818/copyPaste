import Foundation

/// キーボード拡張からのデバッグログを App Groups 経由でメインアプリと共有する
struct KeyboardLogger {
    enum EventType: String {
        case launch     = "🚀 起動"
        case proCheck   = "🔐 Pro確認"
        case loadStart  = "📂 履歴読込開始"
        case loadDone   = "✅ 履歴読込完了"
        case clipSelect = "📋 クリップ選択"
        case paste      = "✏️ ペースト"
        case error      = "❌ エラー"
    }

    static let logKey = "keyboard_debug_logs"
    static let maxEntries = 200
    private static let appGroupID = "group.com.entaku.clipkit"

    // MARK: - Write

    static func log(_ type: EventType, _ message: String = "") {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let ts = ISO8601DateFormatter().string(from: Date())
        let entry: String
        if message.isEmpty {
            entry = "[\(ts)] \(type.rawValue)"
        } else {
            entry = "[\(ts)] \(type.rawValue): \(message)"
        }
        var entries = defaults.stringArray(forKey: logKey) ?? []
        entries.append(entry)
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
        }
        defaults.set(entries, forKey: logKey)
    }

    // MARK: - Read (main app uses these)

    static func entries() -> [String] {
        UserDefaults(suiteName: appGroupID)?.stringArray(forKey: logKey) ?? []
    }

    static func clear() {
        UserDefaults(suiteName: appGroupID)?.removeObject(forKey: logKey)
    }
}
