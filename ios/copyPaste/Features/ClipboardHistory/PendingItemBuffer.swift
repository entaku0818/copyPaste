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

    /// バッファに保持する最大件数（issue #94）。
    ///
    /// PiPセッションが長時間続くとバッファが無制限に伸び、
    /// 1件追加するたびに全件をJSONで読み書きする処理量がO(n²)で増大していた。
    /// これは「PiP中は軽い処理だけにして背景実行の強制終了を避ける」という
    /// このバッファ自体の目的を裏切るため、上限を設けて頭から捨てる。
    /// 本保存（PiP終了時のflush）までの取りこぼし防止が目的なので、
    /// 履歴上限（無料20件）を十分に超える件数があれば足りる。
    static let maxBufferedItems = 50

    /// 直近のバッファ内容をメモリに保持し、appendのたびのJSON decodeを避ける。
    /// 拡張とメインアプリで別プロセスになるが、このバッファを書くのは
    /// メインアプリのreducerだけなので、書き手側のキャッシュとして成立する。
    private static let lock = NSLock()
    private static var cached: [ClipboardItem]?

    static func load() -> [ClipboardItem] {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        guard let data = SharedConstants.sharedDefaults?.data(forKey: key),
              let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            cached = []
            return []
        }
        cached = items
        return items
    }

    static func append(_ item: ClipboardItem) {
        lock.lock()
        defer { lock.unlock() }
        var items = cached ?? {
            guard let data = SharedConstants.sharedDefaults?.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
                return []
            }
            return decoded
        }()
        items.append(item)
        if items.count > maxBufferedItems {
            items.removeFirst(items.count - maxBufferedItems)
        }
        cached = items
        guard let data = try? JSONEncoder().encode(items) else { return }
        SharedConstants.sharedDefaults?.set(data, forKey: key)
    }

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        cached = []
        SharedConstants.sharedDefaults?.removeObject(forKey: key)
    }
}
