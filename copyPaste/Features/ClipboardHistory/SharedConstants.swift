import Foundation

/// メインアプリとKeyboard Extension間で共有する定数
enum SharedConstants {
    /// App Group ID
    /// Xcodeの Signing & Capabilities でこのIDを追加してください
    static let appGroupID = "group.com.entaku.copyPaste"

    /// 共有ストレージのベースディレクトリ名
    static let storageDirectoryName = "ClipboardHistory"
}
