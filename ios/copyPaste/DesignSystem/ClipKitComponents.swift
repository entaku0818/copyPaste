import SwiftUI

/// カラーバッジ付きアイコン（履歴行・ゴミ箱・Paywallの特典行などで使用）
struct IconBadge: View {
    let systemImage: String
    let colors: ClipKitColor.BadgeColors
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ClipKitRadius.badge, style: .continuous)
                .fill(colors.background)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundColor(colors.foreground)
        }
        .frame(width: size, height: size)
    }
}

/// リスト内の行をカードグループとして描画するための位置情報
enum CardRowPosition {
    case single, first, middle, last

    var corners: UnevenRoundedRectangle {
        switch self {
        case .single:
            return UnevenRoundedRectangle(
                topLeadingRadius: ClipKitRadius.card, bottomLeadingRadius: ClipKitRadius.card,
                bottomTrailingRadius: ClipKitRadius.card, topTrailingRadius: ClipKitRadius.card
            )
        case .first:
            return UnevenRoundedRectangle(
                topLeadingRadius: ClipKitRadius.card, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: ClipKitRadius.card
            )
        case .middle:
            return UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0
            )
        case .last:
            return UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: ClipKitRadius.card,
                bottomTrailingRadius: ClipKitRadius.card, topTrailingRadius: 0
            )
        }
    }

    var showsBottomDivider: Bool {
        self == .first || self == .middle
    }

    static func at(_ index: Int, count: Int) -> CardRowPosition {
        if count <= 1 { return .single }
        if index == 0 { return .first }
        if index == count - 1 { return .last }
        return .middle
    }
}

/// `List` の行をIndigoデザインのカードグループ風に見せるモディファイア。
/// swipeActions等のList機能はそのまま使える。
struct CardRowStyle: ViewModifier {
    let position: CardRowPosition
    /// カード内でアイコン幅ぶんインデントして区切り線を引く場合に指定
    var dividerLeadingInset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, ClipKitSpacing.cardPadding)
            .padding(.vertical, ClipKitSpacing.rowVerticalPadding)
            .overlay(alignment: .bottom) {
                if position.showsBottomDivider {
                    Rectangle()
                        .fill(ClipKitColor.separator)
                        .frame(height: 0.5)
                        .padding(.leading, dividerLeadingInset)
                }
            }
            .listRowInsets(EdgeInsets(
                top: 0, leading: ClipKitSpacing.screenPadding,
                bottom: 0, trailing: ClipKitSpacing.screenPadding
            ))
            .listRowSeparator(.hidden)
            .listRowBackground(
                position.corners
                    .fill(ClipKitColor.card)
                    .padding(.horizontal, ClipKitSpacing.screenPadding)
            )
    }
}

extension View {
    /// Listの行をIndigoデザインのカードグループの一部として描画する
    func clipKitCardRow(_ position: CardRowPosition, dividerLeadingInset: CGFloat = 52) -> some View {
        modifier(CardRowStyle(position: position, dividerLeadingInset: dividerLeadingInset))
    }
}

/// カード形式のコンテナ（Listを使わない画面向け）
struct CardGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(ClipKitColor.card)
        .clipShape(RoundedRectangle(cornerRadius: ClipKitRadius.card, style: .continuous))
    }
}

/// CardGroup内の行区切り線（アイコン幅ぶんインデント）
struct CardDivider: View {
    var leadingInset: CGFloat = 52

    var body: some View {
        Rectangle()
            .fill(ClipKitColor.separator)
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}

/// セクションの小見出し（例: "ピン留め" "最近"）
struct SectionCaptionLabel: View {
    let title: String
    var color: Color = ClipKitColor.textSecondary

    var body: some View {
        Text(title)
            .font(ClipKitFont.sectionCaption)
            .tracking(0.6)
            .foregroundColor(color)
            .textCase(nil)
    }
}

/// ブランドグラデーションのプライマリCTAボタン
struct PrimaryGradientButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isEnabled ? ClipKitColor.brandGradient : LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: ClipKitRadius.control, style: .continuous))
            .shadow(color: isEnabled ? ClipKitColor.indigo.opacity(0.4) : .clear, radius: 16, y: 8)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// ダークサーフェスのヒーローカード（Pro訴求・常時起動ステータスなど）
struct DarkHeroCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(ClipKitColor.darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: ClipKitRadius.card + 2, style: .continuous))
    }
}

/// 角丸ピル型のセグメントコントロール（履歴のカテゴリタブなどに使用）
struct PillSegmentedControl<Item: Hashable>: View {
    let items: [Item]
    let label: (Item) -> String
    @Binding var selection: Item

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selection = item }
                } label: {
                    Text(label(item))
                        .font(.system(size: 12.5, weight: selection == item ? .semibold : .regular))
                        .foregroundColor(selection == item ? ClipKitColor.textPrimary : ClipKitColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selection == item ? Color(uiColor: .secondarySystemGroupedBackground) : Color.clear)
                                .shadow(color: .black.opacity(selection == item ? 0.1 : 0), radius: 3, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: ClipKitRadius.segment, style: .continuous)
                .fill(ClipKitColor.controlBackground)
        )
    }
}
