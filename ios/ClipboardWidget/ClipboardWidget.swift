import WidgetKit
import SwiftUI

// MARK: - Shared Constants (Widget用)
private let appGroupID = "group.com.entaku.clipkit"
private let storageDirectoryName = "ClipboardHistory"
private let proStatusKey = "isProUser"

// MARK: - Minimal Item Model
private struct WidgetItem: Identifiable, Decodable {
    let id: UUID
    let timestamp: Date
    let type: String
    var textContent: String?
    var url: URL?
    var fileName: String?
    var isFavorite: Bool = false

    var preview: String {
        switch type {
        case "text": return textContent ?? ""
        case "url": return url?.host ?? url?.absoluteString ?? ""
        case "image": return "画像"
        case "file": return fileName ?? "ファイル"
        default: return ""
        }
    }
}

// MARK: - Storage
private func loadItems() -> [WidgetItem] {
    guard let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupID
    ) else { return [] }
    let metadataURL = containerURL
        .appendingPathComponent(storageDirectoryName)
        .appendingPathComponent("items.json")
    guard let data = try? Data(contentsOf: metadataURL) else { return [] }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return (try? decoder.decode([WidgetItem].self, from: data)) ?? []
}

private func isProUser() -> Bool {
    UserDefaults(suiteName: appGroupID)?.bool(forKey: proStatusKey) ?? false
}

// MARK: - Entry
struct ClipboardEntry: TimelineEntry {
    let date: Date
    fileprivate let items: [WidgetItem]
    let isPro: Bool
}

// MARK: - Provider
struct ClipboardWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClipboardEntry {
        ClipboardEntry(date: Date(), items: sampleItems(), isPro: true)
    }
    func getSnapshot(in context: Context, completion: @escaping (ClipboardEntry) -> Void) {
        completion(ClipboardEntry(date: Date(), items: Array(loadItems().prefix(6)), isPro: isProUser()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClipboardEntry>) -> Void) {
        let entry = ClipboardEntry(date: Date(), items: Array(loadItems().prefix(6)), isPro: isProUser())
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
    private func sampleItems() -> [WidgetItem] {
        [
            WidgetItem(id: UUID(), timestamp: Date(), type: "text", textContent: "サンプルテキスト", isFavorite: true),
            WidgetItem(id: UUID(), timestamp: Date().addingTimeInterval(-60), type: "url", url: URL(string: "https://apple.com")),
            WidgetItem(id: UUID(), timestamp: Date().addingTimeInterval(-120), type: "text", textContent: "別のテキスト"),
        ]
    }
}

// MARK: - Entry View
struct ClipboardWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ClipboardEntry

    var body: some View {
        if entry.isPro {
            switch family {
            case .systemSmall: SmallWidgetView(entry: entry)
            case .systemMedium: MediumWidgetView(entry: entry)
            case .systemLarge: LargeWidgetView(entry: entry)
            case .systemExtraLarge: LargeWidgetView(entry: entry)
            case .accessoryCircular: SmallWidgetView(entry: entry)
            case .accessoryRectangular: SmallWidgetView(entry: entry)
            case .accessoryInline: SmallWidgetView(entry: entry)
            @unknown default: SmallWidgetView(entry: entry)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.title)
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("Pro限定機能").font(.caption).fontWeight(.bold)
                Text("アプリでアップグレード").font(.caption2).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let entry: ClipboardEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.clipboard").foregroundColor(.blue).font(.caption)
                Text("ClipKit").font(.caption).fontWeight(.semibold)
            }
            if let item = entry.items.first {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        typeIcon(item).font(.caption2)
                        if item.isFavorite {
                            Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                        }
                    }
                    Text(item.preview).font(.caption).lineLimit(4).foregroundColor(.primary)
                    Text(widgetTimestamp(item.timestamp)).font(.caption2).foregroundColor(.secondary)
                }
            } else {
                Spacer()
                Text("履歴がありません").font(.caption2).foregroundColor(.secondary)
                Spacer()
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let entry: ClipboardEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "doc.on.clipboard").foregroundColor(.blue)
                Text("ClipKit").font(.headline)
                Spacer()
            }
            if entry.items.isEmpty {
                Spacer()
                HStack { Spacer(); Text("履歴がありません").font(.caption).foregroundColor(.secondary); Spacer() }
                Spacer()
            } else {
                ForEach(Array(entry.items.prefix(3))) { item in
                    HStack(spacing: 8) {
                        typeIcon(item).font(.caption)
                        Text(item.preview).font(.caption).lineLimit(1)
                        Spacer()
                        if item.isFavorite {
                            Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                        }
                        Text(widgetTimestamp(item.timestamp)).font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let entry: ClipboardEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.on.clipboard").foregroundColor(.blue)
                Text("ClipKit").font(.headline)
                Spacer()
                Text("\(entry.items.count)件").font(.caption).foregroundColor(.secondary)
            }
            Divider()
            if entry.items.isEmpty {
                Spacer()
                HStack { Spacer(); Text("履歴がありません").font(.caption).foregroundColor(.secondary); Spacer() }
                Spacer()
            } else {
                ForEach(Array(entry.items.prefix(6))) { item in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(typeColor(item).opacity(0.15)).frame(width: 28, height: 28)
                            typeIcon(item).font(.caption)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.preview).font(.caption).lineLimit(1)
                            Text(widgetTimestamp(item.timestamp)).font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        if item.isFavorite {
                            Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding()
    }
}

private func typeIcon(_ item: WidgetItem) -> some View {
    Group {
        switch item.type {
        case "text": Image(systemName: "doc.text").foregroundColor(.blue)
        case "url": Image(systemName: "link").foregroundColor(.green)
        case "image": Image(systemName: "photo").foregroundColor(.orange)
        default: Image(systemName: "doc").foregroundColor(.purple)
        }
    }
}

private func widgetTimestamp(_ date: Date) -> String {
    let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
    if date < weekAgo {
        return date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP")))
    }
    let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: Date())
    if let day = components.day, day > 0 { return "\(day)日前" }
    if let hour = components.hour, hour > 0 { return "\(hour)時間前" }
    if let minute = components.minute, minute > 0 { return "\(minute)分前" }
    return "たった今"
}

private func typeColor(_ item: WidgetItem) -> Color {
    switch item.type {
    case "text": return .blue
    case "url": return .green
    case "image": return .orange
    default: return .purple
    }
}

// MARK: - Widget
struct ClipboardWidget: Widget {
    let kind: String = "ClipboardWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClipboardWidgetProvider()) { entry in
            ClipboardWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ClipKit")
        .description("クリップボードの履歴をすぐ確認。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
