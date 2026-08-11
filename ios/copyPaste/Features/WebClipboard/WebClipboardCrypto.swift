import CryptoKit
import Foundation

/// Webクリップボード（iPhone → Windows ブラウザ 片方向）のE2E暗号化レイヤ。
///
/// 設計方針（issue #104）:
/// - サーバ（Firestore）が持つのは **暗号文 + TTL のみ**。鍵・平文は一切渡さない
/// - 鍵は iOS では Keychain、ブラウザ側では IndexedDB に保管する（保管処理は各プラットフォーム側の責務）
/// - E2E暗号化は後付けできない設計判断なので v1 の最初から入れる
///
/// この型は「鍵生成・暗号化・復号・QRペアリング用のデータモデル」という、
/// 製品判断（課金設計）やUI/サーバ実装に依存しない純粋なコア部分のみを提供する。
enum WebClipboardCrypto {

    /// 暗号方式のスキーマバージョン。将来の方式変更に備えてペイロードへ含める。
    static let schemaVersion = 1

    // MARK: - 鍵

    /// ペアリングごとに新しく生成する256bit共有鍵。
    static func generateKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }

    /// 鍵をQR/保管用のbase64文字列へ書き出す。
    static func exportKey(_ key: SymmetricKey) -> String {
        return key.withUnsafeBytes { Data($0).base64EncodedString() }
    }

    /// base64文字列から鍵を復元する。長さが不正な場合は nil。
    static func importKey(fromBase64 base64: String) -> SymmetricKey? {
        guard let data = Data(base64Encoded: base64), data.count == 32 else {
            return nil
        }
        return SymmetricKey(data: data)
    }

    // MARK: - 暗号化 / 復号

    /// 平文を AES-GCM で暗号化し、サーバへ渡すペイロードを作る。
    /// 返り値は暗号文のみを含み、平文を一切保持しない。
    static func encrypt(_ plaintext: String, using key: SymmetricKey) throws -> WebClipboardPayload {
        guard let data = plaintext.data(using: .utf8) else {
            throw WebClipboardCryptoError.encodingFailed
        }
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            // combined は 96bit nonce を使う場合のみ生成される。生成失敗は方式不整合とみなす。
            throw WebClipboardCryptoError.encryptionFailed
        }
        return WebClipboardPayload(version: schemaVersion, ciphertext: combined)
    }

    /// ペイロードの暗号文を復号して平文へ戻す。
    static func decrypt(_ payload: WebClipboardPayload, using key: SymmetricKey) throws -> String {
        guard payload.version == schemaVersion else {
            throw WebClipboardCryptoError.unsupportedVersion(payload.version)
        }
        let sealed = try AES.GCM.SealedBox(combined: payload.ciphertext)
        let data = try AES.GCM.open(sealed, using: key)
        guard let plaintext = String(data: data, encoding: .utf8) else {
            throw WebClipboardCryptoError.decodingFailed
        }
        return plaintext
    }
}

/// Firestore へ中継する暗号文ペイロード。
///
/// **このstructは暗号文のみを保持し、平文を含んではならない。**
/// `ciphertext` は AES-GCM の combined 表現（nonce + 暗号文 + 認証タグ）。
/// JSONへエンコードすると `ciphertext` は base64 文字列になる。
struct WebClipboardPayload: Codable, Equatable {
    /// 暗号方式のスキーマバージョン。
    let version: Int
    /// AES-GCM combined（nonce + 暗号文 + タグ）。
    let ciphertext: Data
}

/// QRペアリング用のコード。iPhone がQRとして表示し、ブラウザが読み取る。
///
/// - `channelID`: 中継先（Firestore ドキュメント）を識別するランダムID。秘密情報ではない
/// - `keyBase64`: 共有鍵。**これがQRに含まれる唯一の秘密情報**であり、サーバには渡さない
struct WebClipboardPairingCode: Codable, Equatable {
    let version: Int
    let channelID: String
    let keyBase64: String

    /// 新しいペアリング（鍵 + チャネル）を生成する。
    static func generate(channelID: String) -> (code: WebClipboardPairingCode, key: SymmetricKey) {
        let key = WebClipboardCrypto.generateKey()
        let code = WebClipboardPairingCode(
            version: WebClipboardCrypto.schemaVersion,
            channelID: channelID,
            keyBase64: WebClipboardCrypto.exportKey(key)
        )
        return (code, key)
    }

    /// QRに埋め込むためのコンパクトなJSON文字列へ変換する。
    func encoded() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw WebClipboardCryptoError.encodingFailed
        }
        return string
    }

    /// QRから読み取った文字列を復元する。
    static func decoded(from string: String) throws -> WebClipboardPairingCode {
        guard let data = string.data(using: .utf8) else {
            throw WebClipboardCryptoError.decodingFailed
        }
        return try JSONDecoder().decode(WebClipboardPairingCode.self, from: data)
    }
}

/// Webクリップボード暗号化レイヤのエラー。
enum WebClipboardCryptoError: Error, Equatable {
    case encodingFailed
    case decodingFailed
    case encryptionFailed
    case unsupportedVersion(Int)
}
