import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct ClipboardWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClipboardWidgetEntry {
        ClipboardWidgetEntry(date: Date(), items: sampleItems())
    }

    func getSnapshot(in context: Context, completion: @escaping (ClipboardWidgetEntry) -> Void) {
        let entry = ClipboardWidgetEntry(date: Date(), items: sampleItems())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClipboardWidgetEntry>) -> Void) {
        Task {
            do {
                // Load clipboard items from shared storage
                let items = try await ClipboardStorageManager.shared.load()
                let entry = ClipboardWidgetEntry(date: Date(), items: Array(items.prefix(10)))

                // Update every 5 minutes
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            } catch {
                // Fallback to sample data
                let entry = ClipboardWidgetEntry(date: Date(), items: [])
                let timeline = Timeline(entries: [entry], policy: .never)
                completion(timeline)
            }
        }
    }

    private func sampleItems() -> [ClipboardItem] {
        [
            ClipboardItem(content: "Sample clipboard text", isFavorite: true),
            ClipboardItem(url: URL(string: "https://www.apple.com")!),
            ClipboardItem(content: "Another item")
        ]
    }
}

// MARK: - Timeline Entry
struct ClipboardWidgetEntry: TimelineEntry {
    let date: Date
    let items: [ClipboardItem]
}

// MARK: - Widget Views
struct ClipboardWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ClipboardWidgetProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        @unknown default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (最新1件)
struct SmallWidgetView: View {
    let entry: ClipboardWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.blue)
                Text("Clipboard")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            if let item = entry.items.first {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        itemIcon(for: item)
                        if item.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }

                    Text(itemPreview(for: item))
                        .font(.caption)
                        .lineLimit(3)
                        .foregroundColor(.primary)

                    Text(item.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private func itemIcon(for item: ClipboardItem) -> some View {
        Group {
            switch item.type {
            case .text:
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
            case .url:
                Image(systemName: "link")
                    .foregroundColor(.green)
            case .image:
                Image(systemName: "photo")
                    .foregroundColor(.orange)
            case .file:
                Image(systemName: "doc")
                    .foregroundColor(.purple)
            }
        }
        .font(.caption)
    }

    private func itemPreview(for item: ClipboardItem) -> String {
        switch item.type {
        case .text:
            return item.textContent ?? ""
        case .url:
            return item.url?.absoluteString ?? ""
        case .image:
            return "Image"
        case .file:
            return item.fileName ?? "File"
        }
    }
}

// MARK: - Medium Widget (最新3件)
struct MediumWidgetView: View {
    let entry: ClipboardWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.blue)
                Text("Clipboard History")
                    .font(.headline)
                Spacer()
                Text("\(entry.items.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if entry.items.isEmpty {
                Text("No clipboard items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.items.prefix(3)) { item in
                    HStack(spacing: 8) {
                        itemIcon(for: item)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(itemPreview(for: item))
                                    .font(.caption)
                                    .lineLimit(1)
                                if item.isFavorite {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                }
                            }

                            Text(item.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }
            }
        }
        .padding()
    }

    private func itemIcon(for item: ClipboardItem) -> some View {
        Group {
            switch item.type {
            case .text:
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
            case .url:
                Image(systemName: "link")
                    .foregroundColor(.green)
            case .image:
                Image(systemName: "photo")
                    .foregroundColor(.orange)
            case .file:
                Image(systemName: "doc")
                    .foregroundColor(.purple)
            }
        }
        .font(.title3)
    }

    private func itemPreview(for item: ClipboardItem) -> String {
        switch item.type {
        case .text:
            return item.textContent ?? ""
        case .url:
            return item.url?.host ?? item.url?.absoluteString ?? ""
        case .image:
            return "Image"
        case .file:
            return item.fileName ?? "File"
        }
    }
}

// MARK: - Large Widget (最新6件)
struct LargeWidgetView: View {
    let entry: ClipboardWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.blue)
                Text("Clipboard History")
                    .font(.headline)
                Spacer()
                Text("\(entry.items.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }

            Divider()

            if entry.items.isEmpty {
                VStack {
                    Spacer()
                    Text("No clipboard items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ForEach(entry.items.prefix(6)) { item in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(iconColor(for: item).opacity(0.2))
                                .frame(width: 32, height: 32)

                            itemIcon(for: item)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(itemPreview(for: item))
                                    .font(.caption)
                                    .lineLimit(2)
                                if item.isFavorite {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                }
                            }

                            HStack(spacing: 4) {
                                Text(item.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                if item.type == .text, let text = item.textContent {
                                    Text("・")
                                        .foregroundColor(.secondary)
                                    Text("\(text.count) chars")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer()
        }
        .padding()
    }

    private func itemIcon(for item: ClipboardItem) -> some View {
        Group {
            switch item.type {
            case .text:
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
            case .url:
                Image(systemName: "link")
                    .foregroundColor(.green)
            case .image:
                Image(systemName: "photo")
                    .foregroundColor(.orange)
            case .file:
                Image(systemName: "doc")
                    .foregroundColor(.purple)
            }
        }
        .font(.body)
    }

    private func iconColor(for item: ClipboardItem) -> Color {
        switch item.type {
        case .text: return .blue
        case .url: return .green
        case .image: return .orange
        case .file: return .purple
        }
    }

    private func itemPreview(for item: ClipboardItem) -> String {
        switch item.type {
        case .text:
            return item.textContent ?? ""
        case .url:
            return item.url?.absoluteString ?? ""
        case .image:
            return "Image"
        case .file:
            return item.fileName ?? "File"
        }
    }
}

// MARK: - Widget Configuration
struct ClipboardWidget: Widget {
    let kind: String = "ClipboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClipboardWidgetProvider()) { entry in
            ClipboardWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Clipboard History")
        .description("View your recent clipboard history.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    ClipboardWidget()
} timeline: {
    ClipboardWidgetEntry(date: .now, items: [
        ClipboardItem(content: "Hello World", isFavorite: true),
        ClipboardItem(url: URL(string: "https://www.apple.com")!),
        ClipboardItem(content: "Sample text")
    ])
}

#Preview(as: .systemMedium) {
    ClipboardWidget()
} timeline: {
    ClipboardWidgetEntry(date: .now, items: [
        ClipboardItem(content: "Hello World", isFavorite: true),
        ClipboardItem(url: URL(string: "https://www.apple.com")!),
        ClipboardItem(content: "Sample text")
    ])
}

#Preview(as: .systemLarge) {
    ClipboardWidget()
} timeline: {
    ClipboardWidgetEntry(date: .now, items: [
        ClipboardItem(content: "Hello World Hello World Hello World", isFavorite: true),
        ClipboardItem(url: URL(string: "https://www.apple.com")!),
        ClipboardItem(content: "Sample text"),
        ClipboardItem(content: "Another item"),
        ClipboardItem(url: URL(string: "https://www.google.com")!),
        ClipboardItem(content: "Last item")
    ])
}
