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
                    ForEach(Array(favoriteItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(item: item)
                            .clipKitCardRow(.at(index, count: favoriteItems.count))
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(ClipKitColor.canvas)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !store.isProUser {
                VStack(spacing: 0) {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(ClipKitColor.crown)
                            Text(String(format: String(localized: "favorites.proUpgrade %lld"), Int64(favoriteItems.count)))
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(ClipKitColor.brandGradient)
                        .clipShape(RoundedRectangle(cornerRadius: ClipKitRadius.control, style: .continuous))
                        .padding(.horizontal, ClipKitSpacing.screenPadding)
                        .padding(.top, 12)
                    }
                    .sheet(isPresented: $showPaywall) {
                        PaywallView()
                    }
                    BannerAdView()
                        .frame(height: BannerAdView.adaptiveHeight)
                }
                .background(ClipKitColor.canvas)
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
