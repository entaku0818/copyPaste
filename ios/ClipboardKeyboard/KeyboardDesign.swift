import UIKit

/// キーボード拡張用の配色トークン（本体アプリの ClipKitColor と同じ値を保つ）
enum KeyboardColor {
    static let indigo = UIColor(red: 0x5B / 255, green: 0x5B / 255, blue: 0xD6 / 255, alpha: 1)
    static let indigoLight = UIColor(red: 0x7B / 255, green: 0x78 / 255, blue: 0xF0 / 255, alpha: 1)
    static let crown = UIColor(red: 0xFF / 255, green: 0xE0 / 255, blue: 0x8A / 255, alpha: 1)

    static let badgeBlueBg = UIColor(red: 0xE2 / 255, green: 0xEB / 255, blue: 0xFF / 255, alpha: 1)
    static let badgeBlueFg = UIColor(red: 0x2F / 255, green: 0x6B / 255, blue: 0xFF / 255, alpha: 1)
    static let badgeIndigoBg = UIColor(red: 0xEC / 255, green: 0xEB / 255, blue: 0xFB / 255, alpha: 1)
    static let badgeIndigoFg = indigo
    static let badgeAmberBg = UIColor(red: 0xF3 / 255, green: 0xE9 / 255, blue: 0xD6 / 255, alpha: 1)
    static let badgeAmberFg = UIColor(red: 0xC9 / 255, green: 0x8A / 255, blue: 0x00 / 255, alpha: 1)
}
