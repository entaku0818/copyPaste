import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: ClipKitSpacing.rowGap) {
            itemIcon
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    itemContent

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(ClipKitColor.favorite)
                    }
                }

                HStack(spacing: 4) {
                    Text(timestampText(item.timestamp))
                        .font(ClipKitFont.meta)
                        .foregroundColor(ClipKitColor.textTertiary)

                    if item.sizeInBytes > 0 {
                        Text("・")
                            .font(ClipKitFont.meta)
                            .foregroundColor(ClipKitColor.textTertiary)
                        Text(ByteCountFormatter.string(
                            fromByteCount: item.sizeInBytes,
                            countStyle: .file
                        ))
                        .font(ClipKitFont.meta)
                        .foregroundColor(ClipKitColor.textTertiary)
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
        if item.type == .image, let thumbnail = item.thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: ClipKitRadius.badge, style: .continuous))
        } else {
            IconBadge(systemImage: item.badgeSystemImageName, colors: item.badgeColors, size: 40)
        }
    }

    @ViewBuilder
    private var itemContent: some View {
        switch item.type {
        case .text:
            Text(item.textContent ?? "")
                .font(ClipKitFont.rowTitle)
                .foregroundColor(ClipKitColor.textPrimary)
                .lineLimit(2)

        case .image:
            Text("item.image")
                .font(ClipKitFont.rowTitleEmphasized)
                .foregroundColor(ClipKitColor.textPrimary)

        case .url:
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url?.host ?? "URL")
                    .font(ClipKitFont.rowTitleEmphasized)
                    .foregroundColor(ClipKitColor.textPrimary)
                Text(item.url?.absoluteString ?? "")
                    .lineLimit(1)
                    .font(ClipKitFont.meta)
                    .foregroundColor(ClipKitColor.textTertiary)
            }

        case .file:
            Text(item.fileName ?? String(localized: "item.file"))
                .font(ClipKitFont.rowTitleEmphasized)
                .foregroundColor(ClipKitColor.textPrimary)
        }
    }
}
