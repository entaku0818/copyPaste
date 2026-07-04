import SwiftUI
import ComposableArchitecture
import GoogleMobileAds

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
                    "favorites.empty",
                    systemImage: "star",
                    description: Text("favorites.emptyDescription")
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
                                    Label("favorites.unfavorite", systemImage: "star.slash")
                                }
                                .tint(.gray)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    if let index = store.items.firstIndex(where: { $0.id == item.id }) {
                                        store.send(.removeItems(IndexSet(integer: index)))
                                    }
                                } label: {
                                    Label("item.delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !store.isProUser {
                VStack(spacing: 0) {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                            Text(String(format: String(localized: "favorites.proUpgrade %lld"), Int64(favoriteItems.count)))
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
                    BannerAdView()
                        .frame(height: BannerAdView.adaptiveHeight)
                }
            }
        }
        .navigationTitle("favorites.title")
        .onAppear {
            store.send(.updateProStatus)
        }
        .sheet(item: $selectedItem) { sheetItem in
            ClipboardItemDetailView(
                item: store.items.first(where: { $0.id == sheetItem.id }) ?? sheetItem,
                isProUser: store.isProUser,
                onCopy: {
                    store.send(.copyItem(sheetItem))
                    selectedItem = nil
                },
                onToggleFavorite: {
                    store.send(.toggleFavorite(sheetItem))
                },
                onCopyTransformed: { text, transform in
                    store.send(.copyTransformedText(text, transform))
                },
                onPaywallDismiss: {
                    store.send(.updateProStatus)
                }
            )
        }
    }
}
