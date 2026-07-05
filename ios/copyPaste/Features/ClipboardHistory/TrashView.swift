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
                        Text("trash.description")
                            .font(.system(size: 12.5))
                            .foregroundColor(ClipKitColor.textTertiary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .listRowInsets(EdgeInsets(top: 4, leading: ClipKitSpacing.screenPadding, bottom: 8, trailing: ClipKitSpacing.screenPadding))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        ForEach(Array(store.trashedItems.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 12) {
                                itemIcon(for: item)
                                    .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 3) {
                                    itemContent(for: item)
                                    if let deletedAt = item.deletedAt {
                                        Text("削除: \(deletedAt.formatted(.dateTime.year().month().day().locale(Locale.current)))")
                                            .font(.system(size: 11.5))
                                            .foregroundColor(ClipKitColor.textTertiary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 15))
                                    .foregroundColor(ClipKitColor.indigo)
                            }
                            .clipKitCardRow(.at(index, count: store.trashedItems.count))
                            .swipeActions(edge: .leading) {
                                Button {
                                    store.send(.restoreItem(item))
                                } label: {
                                    Label("item.restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(ClipKitColor.indigo)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.send(.permanentlyDeleteItem(item))
                                } label: {
                                    Label("item.deletePermanently", systemImage: "trash.fill")
                                }
                            }
                        }

                        Text("左スワイプで復元・右スワイプで完全削除")
                            .font(.system(size: 12))
                            .foregroundColor(ClipKitColor.textTertiary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(ClipKitColor.canvas)
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
                        .foregroundColor(ClipKitColor.destructive)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func itemIcon(for item: ClipboardItem) -> some View {
        if item.type == .image, let thumbnail = item.thumbnail {
            Image(uiImage: thumbnail).resizable().scaledToFill()
                .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: ClipKitRadius.badge, style: .continuous))
        } else {
            IconBadge(systemImage: item.badgeSystemImageName, colors: item.badgeColors, size: 40)
        }
    }

    @ViewBuilder
    private func itemContent(for item: ClipboardItem) -> some View {
        switch item.type {
        case .text:
            Text(item.textContent ?? "").lineLimit(1).font(ClipKitFont.rowTitle).foregroundColor(ClipKitColor.textPrimary)
        case .url:
            Text(item.url?.host ?? item.url?.absoluteString ?? "URL").lineLimit(1).font(ClipKitFont.rowTitle).foregroundColor(ClipKitColor.textPrimary)
        case .image:
            Text("item.image").font(ClipKitFont.rowTitle).foregroundColor(ClipKitColor.textPrimary)
        case .file:
            Text(item.fileName ?? String(localized: "item.file")).lineLimit(1).font(ClipKitFont.rowTitle).foregroundColor(ClipKitColor.textPrimary)
        }
    }
}
