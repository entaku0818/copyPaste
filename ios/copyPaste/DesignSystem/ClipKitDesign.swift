import SwiftUI

/// ClipKit Design System — "Indigo" (2026-07 redesign)
/// Source of truth: docs/design/clipkit-design-system.md
/// 参照モックアップ: docs/design/clipkit-redesign-reference.html（案B・Indigo）
enum ClipKitColor {
    // MARK: - Brand

    /// メインブランドカラー（#5B5BD6）
    static let indigo = Color(hex: 0x5B5BD6)
    /// グラデーション用の明るいインディゴ（#7B78F0）
    static let indigoLight = Color(hex: 0x7B78F0)
    /// ブランドグラデーション（135deg, indigoLight → indigo）
    static let brandGradient = LinearGradient(
        colors: [indigoLight, indigo],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Surfaces

    /// 画面の背景（カードを浮かせるキャンバス）
    static let canvas = Color(uiColor: .systemGroupedBackground)
    /// カード・行の背景
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    /// カード内の行区切り線
    static let separator = Color(uiColor: .separator).opacity(0.5)
    /// 検索バー・セグメントコントロールの背景
    static let controlBackground = Color(uiColor: .tertiarySystemFill)
    /// ダークヒーローカード（Pro訴求・常時起動ステータス・Paywall背景）
    static let darkSurface = Color(hex: 0x14142B)

    // MARK: - Text

    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    /// ダークサーフェス上のプライマリテキスト
    static let textOnDark = Color.white
    /// ダークサーフェス上のセカンダリテキスト
    static let textOnDarkSecondary = Color.white.opacity(0.6)
    /// ダークサーフェス上のリンク・アクセント文字
    static let accentOnDark = Color(hex: 0x9D9AF0)

    // MARK: - Semantic

    static let favorite = Color(hex: 0xF5B800)
    static let crown = Color(hex: 0xFFE08A)
    static let destructive = Color(hex: 0xE5484D)
    static let success = Color(hex: 0x22A04C)

    // MARK: - Category badge colors（背景・前景のペア）

    struct BadgeColors {
        let background: Color
        let foreground: Color
    }

    static let badgeIndigo = BadgeColors(background: Color(hex: 0xECEBFB), foreground: indigo)
    static let badgeBlue = BadgeColors(background: Color(hex: 0xE2EBFF), foreground: Color(hex: 0x2F6BFF))
    static let badgePurple = BadgeColors(background: Color(hex: 0xE9E3FB), foreground: Color(hex: 0x7B5BD6))
    static let badgeAmber = BadgeColors(background: Color(hex: 0xF3E9D6), foreground: Color(hex: 0xC98A00))
    static let badgeGreen = BadgeColors(background: Color(hex: 0xDFF3E6), foreground: Color(hex: 0x22A04C))
    /// コード用の反転バッジ（ダーク背景・ミント文字）
    static let badgeCode = BadgeColors(background: Color(hex: 0x1C1C2E), foreground: Color(hex: 0xA8F0D0))
    /// ファイルなどカテゴリ未分類のフォールバック
    static let badgeGray = BadgeColors(
        background: Color(uiColor: .tertiarySystemFill),
        foreground: Color(uiColor: .secondaryLabel)
    )
}

enum ClipKitRadius {
    /// カードグループの角丸
    static let card: CGFloat = 16
    /// アイコンバッジの角丸
    static let badge: CGFloat = 12
    /// CTAボタン・大きめコントロールの角丸
    static let control: CGFloat = 14
    /// セグメントコントロールの角丸
    static let segment: CGFloat = 9
    /// ピル・カプセルの角丸（実質Capsule）
    static let pill: CGFloat = 100
}

enum ClipKitSpacing {
    static let screenPadding: CGFloat = 16
    static let cardPadding: CGFloat = 14
    static let rowVerticalPadding: CGFloat = 11
    static let sectionGap: CGFloat = 18
    static let rowGap: CGFloat = 12
}

enum ClipKitFont {
    /// 画面タイトル（履歴・設定などの大見出し）
    static let screenTitle = Font.system(size: 30, weight: .bold)
    /// カード内タイトル
    static let cardTitle = Font.system(size: 17, weight: .bold)
    /// 行タイトル
    static let rowTitle = Font.system(size: 14.5, weight: .regular)
    /// 行タイトル（強調）
    static let rowTitleEmphasized = Font.system(size: 14.5, weight: .semibold)
    /// メタ情報（日時・バイト数など）
    static let meta = Font.system(size: 12, weight: .regular)
    /// セクションキャプション（"ピン留め"のような小見出し）
    static let sectionCaption = Font.system(size: 11, weight: .bold)
}

// MARK: - Color(hex:)

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        let r = Double((hex & 0xFF0000) >> 16) / 255
        let g = Double((hex & 0x00FF00) >> 8) / 255
        let b = Double(hex & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, opacity: opacity)
    }
}
