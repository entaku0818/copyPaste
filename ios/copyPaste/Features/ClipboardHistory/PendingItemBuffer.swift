import Foundation

/// PiPバックグラウンド監視中に検知したアイテムの軽量チェックポイント。
///
/// PiPによる背景実行（疑似ビデオ通話）は軽い処理を前提にしており、
/// コピー検知のたびにCoreData書き込み（CloudKit同期のトリガーになる）を行うと
/// iOSがこれを不正な背景処理とみなしてPiPセッションを終了させることがある。
/// そのためPiP中はCoreDataへの本保存を遅らせ、App Group UserDefaultsへの
/// 軽量な書き込みだけを即時に行い、プロセスがOSに強制終了された場合の
/// データ消失を防ぐ。PiP終了時（またはアプリ復帰時）にまとめて本保存する。
enum PendingItemBuffer {
    private static let key = "clipkit.pendingPiPItems"

    static func load() -> [ClipboardItem] {
        guard let data = SharedConstants.sharedDefaults?.data(forKey: key),
              let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return []
        }
        return items
    }

    static func append(_ item: ClipboardItem) {
        var items = load()
        items.append(item)
        guard let data = try? JSONEncoder().encode(items) else { return }
        SharedConstants.sharedDefaults?.set(data, forKey: key)
    }

    static func clear() {
        SharedConstants.sharedDefaults?.removeObject(forKey: key)
    }
}
