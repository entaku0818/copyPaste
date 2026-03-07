import SwiftUI
import ComposableArchitecture

struct ClipboardHistoryView: View {
    let store: StoreOf<ClipboardHistoryFeature>
    @State private var showSettings = false

    var body: some View {
        List {
            // Pro状態と履歴件数の表示
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("履歴: \(store.items.count)件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !store.isProUser {
                            Text("無料版: 最大20件")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }

                    Spacer()

                    if !store.isProUser {
                        Button("Proにアップグレード") {
                            store.send(.showPaywall)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                }
                .padding(.vertical, 4)
            }

            // 検索結果の件数表示
            if !store.searchText.isEmpty {
                Section {
                    HStack {
                        Text("\(store.filteredItems.count)件の結果")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("クリア") {
                            store.send(.updateSearchText(""))
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }

            ForEach(store.filteredItems) { item in
                ClipboardItemRow(item: item)
                    .onTapGesture {
                        if item.type == .image {
                            store.send(.showImagePreview(item))
                        } else {
                            store.send(.pasteItem(item))
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            store.send(.toggleFavorite(item))
                        } label: {
                            Label(
                                item.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: item.isFavorite ? "star.slash" : "star.fill"
                            )
                        }
                        .tint(item.isFavorite ? .gray : .yellow)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            if let index = store.items.firstIndex(where: { $0.id == item.id }) {
                                store.send(.removeItems(IndexSet(integer: index)))
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle("ClipKit")
        .searchable(
            text: Binding(
                get: { store.searchText },
                set: { store.send(.updateSearchText($0)) }
            ),
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: store.isProUser ? "Search clipboard history..." : "Search (Pro)"
        )
        .disabled(!store.isProUser) // 無料版では検索バーを無効化
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                }
            }

            ToolbarItem(placement: .principal) {
                if !store.isProUser {
                    Button(action: { store.send(.showPaywall) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Pro")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            }

        }
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(
            isPresented: Binding(
                get: { store.selectedImageItem != nil },
                set: { if !$0 { store.send(.dismissImagePreview) } }
            )
        ) {
            if let imageItem = store.selectedImageItem {
                ImagePreviewView(item: imageItem)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(
            isPresented: Binding(
                get: { store.showPaywall },
                set: { if !$0 { store.send(.dismissPaywall) } }
            )
        ) {
            PaywallView()
        }
        .safeAreaInset(edge: .bottom) {
            // 無料版のみバナー広告を表示
            if !store.isProUser {
                BannerAdView()
                    .frame(height: 50)
            }
        }
    }
} 