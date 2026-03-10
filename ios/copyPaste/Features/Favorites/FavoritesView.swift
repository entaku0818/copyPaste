import SwiftUI
import ComposableArchitecture

struct FavoritesView: View {
    let store: StoreOf<ClipboardHistoryFeature>
    @State private var selectedItem: ClipboardItem?

    private var favoriteItems: [ClipboardItem] {
        store.items.filter { $0.isFavorite }
    }

    @State private var showPaywall = false

    var body: some View {
        Group {
            if favoriteItems.isEmpty {
                ContentUnavailableView(
                    "お気に入りがありません",
                    systemImage: "star",
                    description: Text("履歴を左スワイプするとお気に入りに追加できます")
                )
            } else {
                List {
                    ForEach(favoriteItems) { item in
                        ClipboardItemRow(item: item)
                            .onTapGesture {
                                if item.type == .image {
                                    store.send(.showImagePreview(item))
                                } else {
                                    selectedItem = item
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    store.send(.toggleFavorite(item))
                                } label: {
                                    Label("解除", systemImage: "star.slash")
                                }
                                .tint(.gray)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    if let index = store.items.firstIndex(where: { $0.id == item.id }) {
                                        store.send(.removeItems(IndexSet(integer: index)))
                                    }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !store.isProUser {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                        Text("Pro で無制限に追加 (\(favoriteItems.count)/10)")
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                }
            }
        }
        .navigationTitle("お気に入り")
        .onAppear {
            store.send(.updateProStatus)
        }
        .sheet(item: $selectedItem) { item in
            ClipboardItemDetailView(
                item: item,
                onCopy: {
                    store.send(.copyItem(item))
                    selectedItem = nil
                },
                onToggleFavorite: {
                    store.send(.toggleFavorite(item))
                }
            )
        }
    }
}
