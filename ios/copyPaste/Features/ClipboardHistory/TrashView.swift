import SwiftUI
import ComposableArchitecture

struct TrashView: View {
    let store: StoreOf<ClipboardHistoryFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.trashedItems.isEmpty {
                    ContentUnavailableView(
                        "ゴミ箱は空です",
                        systemImage: "trash",
                        description: Text("削除したアイテムは30日間ここに保存されます")
                    )
                } else {
                    List {
                        ForEach(store.trashedItems) { item in
                            HStack(spacing: 12) {
                                itemIcon(for: item)
                                    .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    itemContent(for: item)
                                    if let deletedAt = item.deletedAt {
                                        Text("削除: \(deletedAt.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    store.send(.restoreItem(item))
                                } label: {
                                    Label("復元", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.send(.permanentlyDeleteItem(item))
                                } label: {
                                    Label("完全削除", systemImage: "trash.fill")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("ゴミ箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                if !store.trashedItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("すべて削除") {
                            store.send(.emptyTrash)
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func itemIcon(for item: ClipboardItem) -> some View {
        switch item.type {
        case .text:
            Image(systemName: "doc.text").font(.title3).foregroundColor(.blue)
        case .image:
            if let thumbnail = item.thumbnail {
                Image(uiImage: thumbnail).resizable().scaledToFill()
                    .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "photo").font(.title3).foregroundColor(.green)
            }
        case .url:
            Image(systemName: "link").font(.title3).foregroundColor(.purple)
        case .file:
            Image(systemName: "doc").font(.title3).foregroundColor(.orange)
        }
    }

    @ViewBuilder
    private func itemContent(for item: ClipboardItem) -> some View {
        switch item.type {
        case .text:
            Text(item.textContent ?? "").lineLimit(1).font(.subheadline)
        case .url:
            Text(item.url?.host ?? item.url?.absoluteString ?? "URL").lineLimit(1).font(.subheadline)
        case .image:
            Text("画像").font(.subheadline)
        case .file:
            Text(item.fileName ?? "ファイル").lineLimit(1).font(.subheadline)
        }
    }
}
