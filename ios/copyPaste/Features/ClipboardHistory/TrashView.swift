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
                        "trash.empty",
                        systemImage: "trash",
                        description: Text("trash.description")
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
                                        Text("削除: \(deletedAt.formatted(.dateTime.year().month().day().locale(Locale.current)))")
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
                                    Label("item.restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.send(.permanentlyDeleteItem(item))
                                } label: {
                                    Label("item.deletePermanently", systemImage: "trash.fill")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("trash.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("button.close") { dismiss() }
                }
                if !store.trashedItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("trash.deleteAll") {
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
            Text("item.image").font(.subheadline)
        case .file:
            Text(item.fileName ?? String(localized: "item.file")).lineLimit(1).font(.subheadline)
        }
    }
}
