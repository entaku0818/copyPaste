import XCTest
@testable import ClipKit

/// EncryptionHelper（AES-GCM 暗号化 + Keychain 鍵管理）のテスト。
///
/// Keychain を伴うため、エンタイトルメントが揃わない実行環境では Keychain 操作が
/// 失敗しうる。その場合は XCTSkip して赤化を避けつつ、可能な環境では暗号の
/// 往復（roundtrip）と改ざん検知を担保する。
final class EncryptionHelperTests: XCTestCase {

    /// Keychain が利用可能か確認し、不可なら以降をスキップする。
    private func requireEncryptionAvailable() throws {
        do {
            _ = try EncryptionHelper.encrypt(Data([0x00]))
        } catch {
            throw XCTSkip("Keychain unavailable in this test environment: \(error)")
        }
    }

    // MARK: - Roundtrip

    func testEncryptDecrypt_roundtrip_succeeds() throws {
        try requireEncryptionAvailable()

        let original = Data("Hello, ClipKit! 🔐 機密データ".utf8)
        let encrypted = try EncryptionHelper.encrypt(original)
        let decrypted = try EncryptionHelper.decrypt(encrypted)

        XCTAssertEqual(decrypted, original, "復号結果は元データと一致すること（データロスがないこと）")
        XCTAssertNotEqual(encrypted, original, "暗号文は平文と異なること")
    }

    func testEncryptDecrypt_roundtrip_emptyData() throws {
        try requireEncryptionAvailable()

        let original = Data()
        let decrypted = try EncryptionHelper.decrypt(EncryptionHelper.encrypt(original))

        XCTAssertEqual(decrypted, original, "空データでも往復で一致すること")
    }

    func testEncryptDecrypt_roundtrip_largeBinaryData() throws {
        try requireEncryptionAvailable()

        var original = Data(count: 256 * 1024)
        original.withUnsafeMutableBytes { buffer in
            for index in 0..<buffer.count { buffer[index] = UInt8(index % 256) }
        }
        let decrypted = try EncryptionHelper.decrypt(EncryptionHelper.encrypt(original))

        XCTAssertEqual(decrypted, original, "大きなバイナリでも往復でビット単位に一致すること")
    }

    func testEncrypt_samedPlaintext_producesDifferentCiphertextButDecryptsBack() throws {
        try requireEncryptionAvailable()

        let original = Data("repeat".utf8)
        let first = try EncryptionHelper.encrypt(original)
        let second = try EncryptionHelper.encrypt(original)

        XCTAssertNotEqual(first, second, "AES-GCM の nonce はランダムなので暗号文は毎回異なること")
        XCTAssertEqual(try EncryptionHelper.decrypt(first), original)
        XCTAssertEqual(try EncryptionHelper.decrypt(second), original)
    }

    // MARK: - Tamper detection

    func testDecrypt_withTamperedData_throwsError() throws {
        try requireEncryptionAvailable()

        let original = Data("integrity-protected".utf8)
        var encrypted = try EncryptionHelper.encrypt(original)
        // 末尾（認証タグ付近）の 1 バイトを反転させて改ざんを再現する
        let lastIndex = encrypted.index(before: encrypted.endIndex)
        encrypted[lastIndex] ^= 0xFF

        XCTAssertThrowsError(try EncryptionHelper.decrypt(encrypted), "改ざんされた暗号文は復号に失敗すること")
    }

    func testDecrypt_withTruncatedData_throwsError() throws {
        try requireEncryptionAvailable()

        let encrypted = try EncryptionHelper.encrypt(Data("truncate-me".utf8))
        let truncated = encrypted.prefix(8) // SealedBox を構成できない短さ

        XCTAssertThrowsError(try EncryptionHelper.decrypt(truncated), "不正な長さのデータは復号に失敗すること")
    }

    // MARK: - Key persistence (Keychain consistency)

    func testKeyConsistency_decryptsCiphertextAcrossSeparateCalls() throws {
        try requireEncryptionAvailable()

        // encrypt と decrypt は別呼び出しで Keychain から同じ鍵を取得する。
        // 鍵が一貫して取り出せていなければ復号できない。
        let original = Data("persisted-key".utf8)
        let encrypted = try EncryptionHelper.encrypt(original)
        let decrypted = try EncryptionHelper.decrypt(encrypted)

        XCTAssertEqual(decrypted, original, "Keychain から取得した鍵が一貫していること")
    }
}
