#if DEBUG
import SwiftUI

// App Store 用スクリーンショットの画面。
//
// 旧モック（ScreenshotPreviewView.swift の Mock* ）は旧デザインのまま残っており、
// タブバー・配色・カテゴリチップが実アプリと食い違っていた。
// ここでは実アプリと同じデザイントークン（ClipKitColor / ClipKitFont / ClipKitSpacing）と
// 部品（IconBadge / CategoryChip）で組み、実機の論理解像度（430×932pt）で描いてから
// 端末フレームに縮小する。文言は言語ごとに明示する（String(localized:) はテストプロセスの
// ロケールに引きずられ、日英を1回の実行で描き分けられないため）。

// MARK: - 共通

private func text(_ language: AppLanguage, _ japanese: String, _ english: String) -> String {
    language == .japanese ? japanese : english
}

/// 実機の論理解像度で描き、与えられた枠に縮小して収める
struct RealScaleScreen<Content: View>: View {
    @ViewBuilder let content: () -> Content

    private let deviceSize = CGSize(width: 430, height: 932)

    var body: some View {
        GeometryReader { geo in
            content()
                .frame(width: deviceSize.width, height: deviceSize.height)
                .scaleEffect(geo.size.width / deviceSize.width, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .environment(\.colorScheme, .light)
    }
}

/// 実機のステータスバー（9:41・電波・Wi-Fi・満充電）
struct StoreShotStatusBar: View {
    var foreground: Color = .black

    var body: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 17, weight: .semibold))
                .padding(.leading, 18)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
                    .font(.system(size: 20, weight: .regular))
            }
            .font(.system(size: 15, weight: .semibold))
            .padding(.trailing, 18)
        }
        .foregroundColor(foreground)
        .padding(.horizontal, 16)
        .frame(height: 54)
    }
}

/// iOS 26 の浮いたタブバー（Liquid Glass）
struct StoreShotTabBar: View {
    enum Tab: CaseIterable {
        case monitoring, history, favorites, snippets, settings
    }

    let language: AppLanguage
    let selected: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                VStack(spacing: 2) {
                    Image(systemName: icon(tab))
                        .font(.system(size: 21, weight: .medium))
                    Text(label(tab))
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(tab == selected ? ClipKitColor.indigo : Color(white: 0.1))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(tab == selected ? 0.07 : 0))
                )
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.92))
                .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
        )
        .overlay(Capsule().stroke(Color.white, lineWidth: 0.5))
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
    }

    private func icon(_ tab: Tab) -> String {
        switch tab {
        case .monitoring: return "play.circle.fill"
        case .history:    return "clock.fill"
        case .favorites:  return "star.fill"
        case .snippets:   return "text.quote"
        case .settings:   return "gearshape.fill"
        }
    }

    private func label(_ tab: Tab) -> String {
        switch tab {
        case .monitoring: return text(language, "常時起動", "Always On")
        case .history:    return text(language, "履歴", "History")
        case .favorites:  return text(language, "お気に入り", "Favorites")
        case .snippets:   return text(language, "定型文", "Snippets")
        case .settings:   return text(language, "設定", "Settings")
        }
    }
}

/// 大見出し（NavigationStack の large title 相当）
private struct LargeTitle: View {
    let title: String
    var leading: String?
    var trailing: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let leading {
                    Text(leading)
                        .font(.system(size: 17))
                        .foregroundColor(ClipKitColor.indigo)
                }
                Spacer()
                if let trailing {
                    Image(systemName: trailing)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(ClipKitColor.indigo)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(ClipKitColor.textPrimary)
                .padding(.horizontal, 20)
        }
    }
}

/// 履歴・お気に入りの1行に必要な情報
struct StoreShotItem: Identifiable {
    let id = UUID()
    let systemImage: String
    let colors: ClipKitColor.BadgeColors
    let title: String
    var subtitle: String?
    let meta: String
    var isFavorite = false
    var emphasized = false

    static func category(
        _ category: ItemCategory, title: String, meta: String, isFavorite: Bool = false
    ) -> StoreShotItem {
        StoreShotItem(
            systemImage: category.systemImageName, colors: category.badgeColors,
            title: title, meta: meta, isFavorite: isFavorite
        )
    }

    static func url(host: String, url: String, meta: String, isFavorite: Bool = false) -> StoreShotItem {
        StoreShotItem(
            systemImage: ItemCategory.url.systemImageName, colors: ItemCategory.url.badgeColors,
            title: host, subtitle: url, meta: meta, isFavorite: isFavorite, emphasized: true
        )
    }
}

/// `ClipboardItemRow` と同じレイアウト
private struct StoreShotRow: View {
    let item: StoreShotItem

    var body: some View {
        HStack(spacing: ClipKitSpacing.rowGap) {
            IconBadge(systemImage: item.systemImage, colors: item.colors, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(item.emphasized ? ClipKitFont.rowTitleEmphasized : ClipKitFont.rowTitle)
                            .foregroundColor(ClipKitColor.textPrimary)
                            .lineLimit(2)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(ClipKitFont.meta)
                                .foregroundColor(ClipKitColor.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(ClipKitColor.favorite)
                    }
                }
                Text(item.meta)
                    .font(ClipKitFont.meta)
                    .foregroundColor(ClipKitColor.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ClipKitSpacing.cardPadding)
        .padding(.vertical, ClipKitSpacing.rowVerticalPadding)
    }
}

/// `clipKitCardRow` で並べたリストと同じ見た目のカード
private struct StoreShotCard<Row: View, Item: Identifiable>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(item)
                if index < items.count - 1 {
                    Rectangle()
                        .fill(ClipKitColor.separator)
                        .frame(height: 0.5)
                        .padding(.leading, ClipKitSpacing.cardPadding + 52)
                }
            }
        }
        .background(ClipKitColor.card)
        .clipShape(RoundedRectangle(cornerRadius: ClipKitRadius.card, style: .continuous))
        .padding(.horizontal, ClipKitSpacing.screenPadding)
    }
}

// MARK: - 履歴

struct StoreShotHistoryView: View {
    let language: AppLanguage

    private var items: [StoreShotItem] {
        let ja = language == .japanese
        return [
            .category(.text,
                      title: text(language, "明日10時から定例MTGです。資料は共有フォルダに置いてあります",
                                  "Team sync moved to 10am tomorrow. Slides are in the shared folder"),
                      meta: text(language, "たった今", "Just now")),
            .url(host: "clipkit-entaku.web.app", url: "https://clipkit-entaku.web.app/",
                 meta: text(language, "3分前", "3 min ago")),
            .category(.email, title: ja ? "tanaka.yuki@example.com" : "alex.morgan@example.com",
                      meta: text(language, "12分前", "12 min ago")),
            .category(.phone, title: ja ? "03-1234-5678" : "(415) 555-0132",
                      meta: text(language, "25分前", "25 min ago")),
            .category(.code, title: ja ? #"git commit -m "fix: ログイン画面の表示崩れ""# : #"git commit -m "fix: login layout""#,
                      meta: text(language, "1時間前", "1 hr ago")),
            .category(.address, title: ja ? "東京都渋谷区神南1-2-3 ClipKitビル 5F" : "1 Infinite Loop, Cupertino, CA 95014",
                      meta: text(language, "2時間前", "2 hr ago")),
            .category(.text,
                      title: text(language, "お世話になっております。先日はお時間をいただきありがとうございました。",
                                  "Thanks again for your time yesterday. Let me know if you have any questions."),
                      meta: text(language, "5時間前", "5 hr ago"), isFavorite: true),
            .url(host: "www.example.com", url: "https://www.example.com/blog/weekly-report",
                 meta: text(language, "1日前", "1 day ago"))
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ClipKitColor.canvas

            VStack(alignment: .leading, spacing: 0) {
                StoreShotStatusBar()
                LargeTitle(title: text(language, "履歴", "History"))

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17))
                    Text(text(language, "履歴を検索...", "Search history..."))
                        .font(.system(size: 17))
                    Spacer()
                }
                .foregroundColor(ClipKitColor.textSecondary)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Capsule().fill(ClipKitColor.controlBackground))
                .padding(.horizontal, ClipKitSpacing.screenPadding)
                .padding(.top, 10)

                HStack(spacing: 8) {
                    CategoryChip(label: text(language, "すべて", "All"), icon: "tray.2", isSelected: true) {}
                    ForEach([ItemCategory.url, .email, .phone, .code], id: \.self) { category in
                        CategoryChip(label: label(category), icon: category.systemImageName, isSelected: false) {}
                    }
                }
                .padding(.horizontal, ClipKitSpacing.screenPadding)
                .padding(.vertical, 12)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()

                StoreShotCard(items: items) { StoreShotRow(item: $0) }
                    .padding(.top, 4)

                Spacer()
            }

            StoreShotTabBar(language: language, selected: .history)
        }
    }

    private func label(_ category: ItemCategory) -> String {
        switch category {
        case .url:     return "URL"
        case .email:   return text(language, "メール", "Email")
        case .phone:   return text(language, "電話", "Phone")
        case .code:    return text(language, "コード", "Code")
        case .address: return text(language, "住所", "Address")
        case .text:    return text(language, "テキスト", "Text")
        }
    }
}

// MARK: - お気に入り

struct StoreShotFavoritesView: View {
    let language: AppLanguage

    private var items: [StoreShotItem] {
        let ja = language == .japanese
        return [
            .category(.address, title: ja ? "〒150-0041 東京都渋谷区神南1-2-3 ClipKitビル 5F" : "1 Infinite Loop, Cupertino, CA 95014",
                      meta: text(language, "2日前", "2 days ago"), isFavorite: true),
            .category(.text,
                      title: text(language, "お世話になっております。株式会社ClipKitの田中です。",
                                  "Hi, this is Alex from ClipKit. Thanks for reaching out!"),
                      meta: text(language, "3日前", "3 days ago"), isFavorite: true),
            .category(.email, title: ja ? "tanaka.yuki@example.com" : "alex.morgan@example.com",
                      meta: text(language, "4日前", "4 days ago"), isFavorite: true),
            .url(host: "meet.example.com", url: "https://meet.example.com/abc-defg-hij",
                 meta: text(language, "5日前", "5 days ago"), isFavorite: true),
            .category(.text,
                      title: text(language, "振込先：ClipKit銀行 渋谷支店 普通 1234567",
                                  "Wire to: ClipKit Bank, Acct 1234567, Routing 021000021"),
                      meta: text(language, "6日前", "6 days ago"), isFavorite: true),
            .category(.phone, title: ja ? "090-1234-5678" : "(415) 555-0132",
                      meta: text(language, "6日前", "6 days ago"), isFavorite: true),
            .category(.code, title: "ssh deploy@10.0.1.24 -p 2222",
                      meta: text(language, "7日前", "7 days ago"), isFavorite: true),
            .url(host: "docs.example.com", url: "https://docs.example.com/clipkit-redesign",
                 meta: "2025/9/28", isFavorite: true),
            .category(.text,
                      title: text(language, "Wi-Fi：ClipKit-Office ／ パスワードは総務まで",
                                  "Wi-Fi: ClipKit-Office (ask IT for the password)"),
                      meta: "2025/9/21", isFavorite: true)
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ClipKitColor.canvas

            VStack(alignment: .leading, spacing: 0) {
                StoreShotStatusBar()
                LargeTitle(title: text(language, "お気に入り", "Favorites"))
                StoreShotCard(items: items) { StoreShotRow(item: $0) }
                    .padding(.top, 16)
                Spacer()
            }

            StoreShotTabBar(language: language, selected: .favorites)
        }
    }
}

// MARK: - 定型文

struct StoreShotSnippetsView: View {
    let language: AppLanguage

    private struct Snippet: Identifiable {
        let id = UUID()
        let title: String
        let content: String
    }

    private var snippets: [Snippet] {
        language == .japanese ? [
            Snippet(title: "挨拶", content: "お世話になっております。株式会社ClipKitの田中です。"),
            Snippet(title: "日程調整", content: "以下の日程でご都合いかがでしょうか。\n・10月14日（火）14:00〜15:00"),
            Snippet(title: "お礼", content: "本日はお忙しい中お時間をいただき、誠にありがとうございました。"),
            Snippet(title: "住所", content: "〒150-0041 東京都渋谷区神南1-2-3 ClipKitビル 5F"),
            Snippet(title: "署名", content: "田中 由紀｜株式会社ClipKit\nTEL 03-1234-5678"),
            Snippet(title: "日報", content: "【日報 {日付}】\n本日の作業："),
            Snippet(title: "遅刻連絡", content: "電車遅延のため10分ほど遅れます。申し訳ありません。"),
            Snippet(title: "配送先", content: "田中 由紀\n〒150-0041 東京都渋谷区神南1-2-3"),
            Snippet(title: "定例リンク", content: "https://meet.example.com/abc-defg-hij")
        ] : [
            Snippet(title: "Greeting", content: "Hi there, thanks for reaching out! I'll get back to you shortly."),
            Snippet(title: "Scheduling", content: "Would any of these times work for you?\n• Tue, Oct 14, 2:00–3:00 PM"),
            Snippet(title: "Thank you", content: "Thank you so much for taking the time to meet today."),
            Snippet(title: "Address", content: "1 Infinite Loop, Cupertino, CA 95014"),
            Snippet(title: "Signature", content: "Alex Morgan | ClipKit Inc.\n(415) 555-0132"),
            Snippet(title: "Daily report", content: "Daily report {date}\nToday I worked on:"),
            Snippet(title: "Running late", content: "Running about 10 minutes late, sorry about that!"),
            Snippet(title: "Shipping", content: "Alex Morgan\n1 Infinite Loop, Cupertino, CA 95014"),
            Snippet(title: "Meeting link", content: "https://meet.example.com/abc-defg-hij")
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ClipKitColor.canvas

            VStack(alignment: .leading, spacing: 0) {
                StoreShotStatusBar()
                LargeTitle(
                    title: text(language, "定型文", "Snippets"),
                    leading: text(language, "編集", "Edit"),
                    trailing: "plus"
                )
                StoreShotCard(items: snippets) { snippet in
                    HStack(spacing: ClipKitSpacing.rowGap) {
                        IconBadge(systemImage: "text.quote", colors: ClipKitColor.badgeIndigo, size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(snippet.title)
                                .font(ClipKitFont.rowTitleEmphasized)
                                .foregroundColor(ClipKitColor.textPrimary)
                                .lineLimit(1)
                            Text(snippet.content)
                                .font(ClipKitFont.meta)
                                .foregroundColor(ClipKitColor.textTertiary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, ClipKitSpacing.cardPadding)
                    .padding(.vertical, ClipKitSpacing.rowVerticalPadding)
                }
                .padding(.top, 16)
                Spacer()
            }

            StoreShotTabBar(language: language, selected: .snippets)
        }
    }
}

// MARK: - キーボード

/// 他アプリ（メッセージの入力中）の上に ClipKit キーボードを出した画面。
/// キーボードは KeyboardViewController と同じ寸法（カード 120×80・帯 100pt・操作バー 44pt）。
struct StoreShotKeyboardView: View {
    let language: AppLanguage

    private struct Card: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let text: String
    }

    private var cards: [Card] {
        let ja = language == .japanese
        return [
            Card(icon: "link", tint: Color(hex: 0x2F6BFF), text: "https://www.example.com/blog/weekly-report"),
            Card(icon: "doc.text", tint: ClipKitColor.indigo,
                 text: text(language, "明日10時から定例MTGです。資料は共有フォルダに", "Team sync moved to 10am tomorrow")),
            Card(icon: "doc.text", tint: ClipKitColor.indigo,
                 text: ja ? "東京都渋谷区神南1-2-3 ClipKitビル 5F" : "1 Infinite Loop, Cupertino, CA"),
            Card(icon: "doc.text", tint: ClipKitColor.indigo, text: ja ? "tanaka.yuki@example.com" : "alex.morgan@example.com")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // ホストアプリ（メッセージ風の会話）
            VStack(spacing: 0) {
                StoreShotStatusBar()
                VStack(spacing: 2) {
                    Circle()
                        .fill(LinearGradient(colors: [Color(white: 0.75), Color(white: 0.6)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 48, height: 48)
                        .overlay(Text(text(language, "佐", "S")).font(.system(size: 20, weight: .semibold)).foregroundColor(.white))
                    Text(text(language, "佐藤さん", "Sam"))
                        .font(.system(size: 12))
                        .foregroundColor(ClipKitColor.textPrimary)
                }
                .padding(.bottom, 10)

                Rectangle().fill(ClipKitColor.separator).frame(height: 0.5)

                VStack(spacing: 8) {
                    Text(text(language, "今日 14:32", "Today 2:32 PM"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ClipKitColor.textSecondary)
                        .padding(.bottom, 4)
                    bubble(text(language, "お疲れさま！明日の件だけど", "Hey! About tomorrow"), isMine: false)
                    bubble(text(language, "うん、10時からだよね", "Yep, 10am right?"), isMine: true)
                    bubble(text(language, "そうそう。資料のリンク、さっき送ってくれたやつもう一回もらえる？",
                                        "Yes! Could you resend the slides link from earlier?"), isMine: false)
                    bubble("https://www.example.com/blog/weekly-report", isMine: true)
                    bubble(text(language, "ありがとう！あと場所どこだっけ？", "Thanks! And where are we meeting?"), isMine: false)
                    bubble(text(language, "ちょっと待ってね、送るね", "One sec, sending it now"), isMine: true)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                Spacer()

                // 入力欄
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(ClipKitColor.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ClipKitColor.controlBackground))
                    HStack(spacing: 0) {
                        Text(text(language, "東京都渋谷区神南1-2-3 ClipKitビル 5F", "1 Infinite Loop, Cupertino, CA"))
                            .font(.system(size: 16))
                            .foregroundColor(ClipKitColor.textPrimary)
                            .lineLimit(1)
                        Rectangle().fill(Color(hex: 0x2F6BFF)).frame(width: 2, height: 20)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .overlay(Capsule().stroke(Color(white: 0.8), lineWidth: 1))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color.white)

            keyboard
        }
    }

    private func bubble(_ message: String, isMine: Bool) -> some View {
        HStack {
            if isMine { Spacer(minLength: 60) }
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(isMine ? .white : ClipKitColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isMine ? Color(hex: 0x2F6BFF) : Color(white: 0.91))
                )
            if !isMine { Spacer(minLength: 60) }
        }
    }

    private var keyboard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ForEach(cards) { card in
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: card.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(card.tint)
                            .frame(width: 16, height: 16)
                        Text(card.text)
                            .font(.system(size: 11))
                            .foregroundColor(ClipKitColor.textPrimary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .frame(width: 120, height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    )
                }
            }
            .padding(.horizontal, 12)
            .frame(width: 430, height: 100, alignment: .leading)
            .clipped()
            .background(Color(uiColor: .secondarySystemBackground))

            HStack {
                HStack(spacing: 0) {
                    Text(text(language, "履歴", "History"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ClipKitColor.indigo)
                        .frame(width: 76, height: 28)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white).shadow(color: .black.opacity(0.12), radius: 2, y: 1))
                    Text(text(language, "定型文", "Snippets"))
                        .font(.system(size: 13))
                        .foregroundColor(ClipKitColor.textPrimary)
                        .frame(width: 76, height: 28)
                }
                .padding(2)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color(white: 0.93)))
                Spacer()
                Image(systemName: "globe")
                    .font(.system(size: 22))
                    .foregroundColor(ClipKitColor.textPrimary)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color.white)

            // ホームインジケータぶんの余白（キーボードの下端）
            Color.white.frame(height: 34)
        }
    }
}

// MARK: - ウィジェット

/// ホーム画面に ClipKit ウィジェット（large / medium）を置いた画面。
/// 中身は ClipboardWidget の LargeWidgetView / MediumWidgetView と同じレイアウト。
struct StoreShotWidgetView: View {
    let language: AppLanguage

    private struct Row: Identifiable {
        let id = UUID()
        let type: String
        let preview: String
        let time: String
        var isFavorite = false
    }

    private var rows: [Row] {
        let ja = language == .japanese
        return [
            Row(type: "text", preview: text(language, "明日10時から定例MTGです。資料は共有フォルダに", "Team sync moved to 10am tomorrow"),
                time: text(language, "たった今", "Just now")),
            Row(type: "url", preview: "https://www.example.com/blog/weekly-report",
                time: text(language, "3分前", "3 min ago")),
            Row(type: "text", preview: ja ? "tanaka.yuki@example.com" : "alex.morgan@example.com",
                time: text(language, "12分前", "12 min ago")),
            Row(type: "image", preview: text(language, "画像", "Image"), time: text(language, "40分前", "40 min ago")),
            Row(type: "text", preview: ja ? "東京都渋谷区神南1-2-3 ClipKitビル 5F" : "1 Infinite Loop, Cupertino, CA",
                time: text(language, "2時間前", "2 hr ago"), isFavorite: true),
            Row(type: "url", preview: "https://clipkit-entaku.web.app/", time: text(language, "1日前", "1 day ago"))
        ]
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(hex: 0x7B78F0), Color(hex: 0x5B5BD6), Color(hex: 0xE58BB5)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                StoreShotStatusBar(foreground: .white)

                large
                    .padding(.top, 16)

                medium
                    .padding(.top, 22)

                Spacer()
            }
            .padding(.horizontal, 26)
        }
    }

    private func widgetCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            )
    }

    private var large: some View {
        widgetCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.on.clipboard").foregroundColor(.blue)
                    Text("ClipKit").font(.headline)
                    Spacer()
                    Text(text(language, "6件", "6 items")).font(.caption).foregroundColor(.secondary)
                }
                Divider()
                ForEach(rows) { row in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(color(row.type).opacity(0.15)).frame(width: 28, height: 28)
                            icon(row.type).font(.caption)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.preview).font(.caption).lineLimit(1)
                            Text(row.time).font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        if row.isFavorite {
                            Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                        }
                    }
                }
            }
            .padding()
            .frame(width: 378, height: 378, alignment: .top)
        }
    }

    private var medium: some View {
        widgetCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "doc.on.clipboard").foregroundColor(.blue)
                    Text("ClipKit").font(.headline)
                    Spacer()
                }
                ForEach(rows.prefix(3)) { row in
                    HStack(spacing: 8) {
                        icon(row.type).font(.caption)
                        Text(row.preview).font(.caption).lineLimit(1)
                        Spacer()
                        Text(row.time).font(.caption2).foregroundColor(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .frame(width: 378, height: 178, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func icon(_ type: String) -> some View {
        switch type {
        case "text":  Image(systemName: "doc.text").foregroundColor(.blue)
        case "url":   Image(systemName: "link").foregroundColor(.green)
        case "image": Image(systemName: "photo").foregroundColor(.orange)
        default:      Image(systemName: "doc").foregroundColor(.purple)
        }
    }

    private func color(_ type: String) -> Color {
        switch type {
        case "text":  return .blue
        case "url":   return .green
        case "image": return .orange
        default:      return .purple
        }
    }
}
#endif
