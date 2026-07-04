import Foundation

enum CloudKitSyncMode: String, CaseIterable {
    case disabled
    case all

    var displayName: String {
        switch self {
        case .disabled: return String(localized: "cloudKitSync.disabled")
        case .all: return String(localized: "cloudKitSync.all")
        }
    }

    var isEnabled: Bool { self != .disabled }

    static var current: CloudKitSyncMode {
        get {
            // 未設定時は「同期する」。「同期しない」は明示的に選んだ場合のみ
            guard let raw = UserDefaults.standard.string(forKey: "cloudKitSyncMode") else {
                return .all
            }
            if let mode = CloudKitSyncMode(rawValue: raw) {
                return mode
            }
            // 旧バージョンの "textAndURL"（テキスト・URLのみ）は「同期する」へマイグレーション
            return raw == "textAndURL" ? .all : .disabled
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "cloudKitSyncMode")
        }
    }
}
