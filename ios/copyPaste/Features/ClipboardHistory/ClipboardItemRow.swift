import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 12) {
            // サムネイル/アイコン
            itemIcon
                .frame(width: 50, height: 50)

            // コンテンツ
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    itemContent

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                HStack(spacing: 4) {
                    Text(timestampText(item.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if item.sizeInBytes > 0 {
                        Text("・")
                            .foregroundColor(.secondary)
                        Text(ByteCountFormatter.string(
                            fromByteCount: item.sizeInBytes,
                            countStyle: .file
                        ))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private func timestampText(_ date: Date) -> String {
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        if date < weekAgo {
            return date.formatted(.dateTime.year().month().day().locale(Locale.current))
        } else {
            let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: Date())
            if let day = components.day, day > 0 { return String(format: String(localized: "time.days %lld"), Int64(day)) }
            if let hour = components.hour, hour > 0 { return String(format: String(localized: "time.hours %lld"), Int64(hour)) }
            if let minute = components.minute, minute > 0 { return String(format: String(localized: "time.minutes %lld"), Int64(minute)) }
            return String(localized: "time.justnow")
        }
    }

    @ViewBuilder
    private var itemIcon: some View {
        switch item.type {
        case .text:
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundColor(.blue)

        case .image:
            if let thumbnail = item.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.green)
            }

        case .url:
            Image(systemName: "link")
                .font(.title2)
                .foregroundColor(.purple)

        case .file:
            Image(systemName: "doc")
                .font(.title2)
                .foregroundColor(.orange)
        }
    }

    @ViewBuilder
    private var itemContent: some View {
        switch item.type {
        case .text:
            Text(item.textContent ?? "")
                .lineLimit(2)

        case .image:
            Text("item.image")
                .font(.headline)

        case .url:
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url?.host ?? "URL")
                    .font(.headline)
                Text(item.url?.absoluteString ?? "")
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        case .file:
            Text(item.fileName ?? String(localized: "item.file"))
                .font(.headline)
        }
    }
}
