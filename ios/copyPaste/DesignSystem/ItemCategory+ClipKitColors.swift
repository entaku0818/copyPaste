import SwiftUI

extension ItemCategory {
    /// 履歴行・詳細画面のアイコンバッジ配色
    var badgeColors: ClipKitColor.BadgeColors {
        switch self {
        case .url:     return ClipKitColor.badgeBlue
        case .email:   return ClipKitColor.badgePurple
        case .phone:   return ClipKitColor.badgeGreen
        case .code:    return ClipKitColor.badgeCode
        case .address: return ClipKitColor.badgeAmber
        case .text:    return ClipKitColor.badgeIndigo
        }
    }
}

extension ClipboardItemType {
    /// カテゴリ未設定時のフォールバック配色・アイコン
    var fallbackBadgeColors: ClipKitColor.BadgeColors {
        switch self {
        case .text:  return ClipKitColor.badgeIndigo
        case .url:   return ClipKitColor.badgeBlue
        case .image: return ClipKitColor.badgeAmber
        case .file:  return ClipKitColor.badgeGray
        }
    }

    var fallbackSystemImageName: String {
        switch self {
        case .text:  return "doc.text"
        case .url:   return "link"
        case .image: return "photo"
        case .file:  return "doc"
        }
    }
}

extension ClipboardItem {
    /// 行アイコンに使う配色（カテゴリがあればカテゴリ優先、なければ種類でフォールバック）
    var badgeColors: ClipKitColor.BadgeColors {
        if type == .image || type == .file { return type.fallbackBadgeColors }
        return category?.badgeColors ?? type.fallbackBadgeColors
    }

    /// 行アイコンに使うSF Symbol名
    var badgeSystemImageName: String {
        if type == .image || type == .file { return type.fallbackSystemImageName }
        return category?.systemImageName ?? type.fallbackSystemImageName
    }
}
