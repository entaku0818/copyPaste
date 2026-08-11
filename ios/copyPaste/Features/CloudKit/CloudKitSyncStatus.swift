import Foundation

/// iCloud同期の状態をユーザーに見せるための記録（issue #103）。
///
/// これまで同期は「有効/無効」を選べるだけで、実際に同期されたのかどうかを
/// 知る手段がなかった。複数端末機能は状態が見えないと
/// 「同期されていないのでは」という不信につながるため、
/// 他端末の変更を取り込んだ時刻を残して設定画面に表示する。
///
/// `.NSPersistentStoreRemoteChange`（他端末の変更が取り込まれた通知）を
/// 受けた時点を「最終同期」として扱う。CloudKitは自前の同期完了APIを
/// 公開していないため、アプリ側から観測できるもっとも確かな同期の証拠がこれになる。
enum CloudKitSyncStatus {
    private static let lastSyncedAtKey = "clipkit.lastRemoteSyncDate"

    /// 他端末の変更を最後に取り込んだ時刻。一度も同期していなければ nil。
    static var lastSyncedAt: Date? {
        get {
            let raw = UserDefaults.standard.double(forKey: lastSyncedAtKey)
            guard raw > 0 else { return nil }
            return Date(timeIntervalSince1970: raw)
        }
        set {
            guard let newValue else {
                UserDefaults.standard.removeObject(forKey: lastSyncedAtKey)
                return
            }
            UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: lastSyncedAtKey)
        }
    }
}
