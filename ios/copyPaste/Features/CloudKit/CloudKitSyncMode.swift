import Foundation

enum CloudKitSyncMode: String, CaseIterable {
    case disabled = "disabled"
    case textAndURL = "textAndURL"
    case all = "all"

    var displayName: String {
        switch self {
        case .disabled: return "同期しない"
        case .textAndURL: return "テキスト・URLのみ"
        case .all: return "画像・ファイルも含む全て"
        }
    }

    var includesMedia: Bool { self == .all }
    var isEnabled: Bool { self != .disabled }

    static var current: CloudKitSyncMode {
        get {
            let raw = UserDefaults.standard.string(forKey: "cloudKitSyncMode") ?? "disabled"
            return CloudKitSyncMode(rawValue: raw) ?? .disabled
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "cloudKitSyncMode")
        }
    }
}
