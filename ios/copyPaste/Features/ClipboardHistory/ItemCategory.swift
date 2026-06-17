import Foundation

enum ItemCategory: String, Codable, CaseIterable, Equatable {
    case url        = "url"
    case email      = "email"
    case phone      = "phone"
    case code       = "code"
    case address    = "address"
    case text       = "text"

    var displayName: String {
        switch self {
        case .url:     return String(localized: "category.url")
        case .email:   return String(localized: "category.email")
        case .phone:   return String(localized: "category.phone")
        case .code:    return String(localized: "category.code")
        case .address: return String(localized: "category.address")
        case .text:    return String(localized: "category.text")
        }
    }

    var systemImageName: String {
        switch self {
        case .url:     return "link"
        case .email:   return "envelope"
        case .phone:   return "phone"
        case .code:    return "chevron.left.forwardslash.chevron.right"
        case .address: return "mappin"
        case .text:    return "doc.text"
        }
    }
}
