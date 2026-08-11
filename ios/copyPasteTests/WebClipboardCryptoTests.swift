import CryptoKit
import XCTest
@testable import ClipKit

final class WebClipboardCryptoTests: XCTestCase {

    // MARK: - ラウンドトリップ

    func testEncryptDecryptRoundtrip() throws {
        let key = WebClipboardCrypto.generateKey()
        let plaintext = "秘密のクリップボード内容 🔐 https://example.com/token=abc123"

        let payload = try WebClipboardCrypto.encrypt(plaintext, using: key)
        let decrypted = try WebClipboardCrypto.decrypt(payload, using: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptRoundtrip_emptyString() throws {
        let key = WebClipboardCrypto.generateKey()
        let payload = try WebClipboardCrypto.encrypt("", using: key)
        XCTAssertEqual(try WebClipboardCrypto.decrypt(payload, using: key), "")
    }

    func testDecryptWithWrongKeyFails() throws {
        let key = WebClipboardCrypto.generateKey()
        let otherKey = WebClipboardCrypto.generateKey()
        let payload = try WebClipboardCrypto.encrypt("hello", using: key)

        XCTAssertThrowsError(try WebClipboardCrypto.decrypt(payload, using: otherKey))
    }

    func testEncryptProducesDifferentCiphertextEachTime() throws {
        // AES-GCM のランダムnonceにより、同じ平文でも毎回異なる暗号文になる。
        let key = WebClipboardCrypto.generateKey()
        let a = try WebClipboardCrypto.encrypt("same", using: key)
        let b = try WebClipboardCrypto.encrypt("same", using: key)
        XCTAssertNotEqual(a.ciphertext, b.ciphertext)
    }

    // MARK: - サーバへ渡すペイロードに平文が含まれないことの担保

    func testServerPayloadContainsNoPlaintext() throws {
        let key = WebClipboardCrypto.generateKey()
        let plaintext = "SECRET-PLAINTEXT-MARKER-9f8e7d6c"

        let payload = try WebClipboardCrypto.encrypt(plaintext, using: key)

        // Firestore へ送るのは JSON エンコードされたペイロード。その全バイトに平文が現れてはならない。
        let json = try JSONEncoder().encode(payload)
        let jsonString = String(data: json, encoding: .utf8) ?? ""

        XCTAssertFalse(jsonString.contains(plaintext), "JSONペイロードに平文が含まれてはならない")
        XCTAssertFalse(payload.ciphertext.range(of: Data(plaintext.utf8)) != nil, "暗号文バイト列に平文が含まれてはならない")

        // ペイロードのフィールドは version と ciphertext のみ（鍵・平文を運ぶフィールドが無い）。
        guard let object = try JSONSerialization.jsonObject(with: json) as? [String: Any] else {
            return XCTFail("ペイロードがJSONオブジェクトではない")
        }
        XCTAssertEqual(Set(object.keys), ["version", "ciphertext"])
    }

    // MARK: - 鍵のエクスポート / インポート

    func testKeyExportImportRoundtrip() throws {
        let key = WebClipboardCrypto.generateKey()
        let base64 = WebClipboardCrypto.exportKey(key)
        let restored = try XCTUnwrap(WebClipboardCrypto.importKey(fromBase64: base64))

        // 復元した鍵で暗号化 → 元の鍵で復号できること（＝同一鍵）。
        let payload = try WebClipboardCrypto.encrypt("roundtrip", using: restored)
        XCTAssertEqual(try WebClipboardCrypto.decrypt(payload, using: key), "roundtrip")
    }

    func testImportKeyRejectsInvalidLength() {
        XCTAssertNil(WebClipboardCrypto.importKey(fromBase64: "aGVsbG8="))       // "hello" = 5バイト
        XCTAssertNil(WebClipboardCrypto.importKey(fromBase64: "not-base64!!!"))
    }

    // MARK: - QRペアリングコード

    func testPairingCodeEncodeDecodeRoundtrip() throws {
        let (code, _) = WebClipboardPairingCode.generate(channelID: "channel-abc")
        let encoded = try code.encoded()
        let decoded = try WebClipboardPairingCode.decoded(from: encoded)

        XCTAssertEqual(decoded, code)
        XCTAssertEqual(decoded.channelID, "channel-abc")
        XCTAssertNotNil(WebClipboardCrypto.importKey(fromBase64: decoded.keyBase64))
    }

    func testDecryptRejectsUnsupportedVersion() throws {
        let key = WebClipboardCrypto.generateKey()
        let valid = try WebClipboardCrypto.encrypt("x", using: key)
        let tampered = WebClipboardPayload(version: 999, ciphertext: valid.ciphertext)

        XCTAssertThrowsError(try WebClipboardCrypto.decrypt(tampered, using: key)) { error in
            XCTAssertEqual(error as? WebClipboardCryptoError, .unsupportedVersion(999))
        }
    }
}
