import Foundation

/// メインアプリとKeyboard Extension、Widget間で共有する定数
enum SharedConstants {
    /// App Group ID
    /// Xcodeの Signing & Capabilities でこのIDを追加してください
    static let appGroupID = "group.com.entaku.copyPaste"

    /// 共有ストレージのベースディレクトリ名
    static let storageDirectoryName = "ClipboardHistory"

    /// Pro状態を保存するUserDefaultsキー
    static let proStatusKey = "isProUser"

    /// App GroupのUserDefaults
    static var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupID)
    }
}
