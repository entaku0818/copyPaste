import SwiftUI
import ComposableArchitecture

struct ClipboardHistoryView: View {
    let store: StoreOf<ClipboardHistoryFeature>
    @State private var selectedItem: ClipboardItem?

    var body: some View {
        List {
            // 検索結果件数
            if !store.searchText.isEmpty {
                Section {
                    HStack {
                        Text(String(format: String(localized: "search.results %lld"), Int64(store.filteredItems.count)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("search.clear") {
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
                            selectedItem = item
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            store.send(.toggleFavorite(item))
                        } label: {
                            Label(
                                item.isFavorite ? String(localized: "item.unfavorite") : String(localized: "item.favorite"),
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
                            Label("item.delete", systemImage: "trash")
                        }
                    }
            }

            // 無料版: Pro誘導バナー
            if !store.isProUser {
                Section {
                    Button {
                        store.send(.showPaywall)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("upgrade.title")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("upgrade.description")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("history.title")
        .searchable(
            text: Binding(
                get: { store.searchText },
                set: { store.send(.updateSearchText($0)) }
            ),
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "search.placeholder"
        )
        .safeAreaInset(edge: .top) {
            CategoryFilterBar(
                selectedCategory: store.selectedCategory,
                onSelect: { store.send(.selectCategory($0)) }
            )
        }
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(item: $selectedItem) { sheetItem in
            // store.items から最新の item を取得してDetail に渡す
            // （let item のままだと toggleFavorite 後に isFavorite が更新されない）
            ClipboardItemDetailView(
                item: store.items.first(where: { $0.id == sheetItem.id }) ?? sheetItem,
                onCopy: {
                    store.send(.copyItem(sheetItem))
                    selectedItem = nil
                },
                onToggleFavorite: {
                    store.send(.toggleFavorite(sheetItem))
                }
            )
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
        .sheet(
            isPresented: Binding(
                get: { store.showPaywall },
                set: { if !$0 { store.send(.dismissPaywall) } }
            )
        ) {
            PaywallView()
        }
        .sheet(
            isPresented: Binding(
                get: { store.showSatisfactionPrompt },
                set: { if !$0 { store.send(.dismissSatisfactionPrompt) } }
            )
        ) {
            SatisfactionPromptView(
                onSatisfied: { store.send(.satisfactionResponsePositive) },
                onUnsatisfied: { store.send(.satisfactionResponseNegative) }
            )
        }
        .sheet(
            isPresented: Binding(
                get: { store.showFeedbackForm },
                set: { if !$0 { store.send(.dismissFeedbackForm) } }
            )
        ) {
            FeedbackFormView()
        }
        .safeAreaInset(edge: .bottom) {
            if !store.isProUser {
                BannerAdView()
                    .frame(height: BannerAdView.adaptiveHeight)
            }
        }
    }
}

// MARK: - Item Detail View

struct ClipboardItemDetailView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // コンテンツ本文
                    Group {
                        switch item.type {
                        case .text:
                            Text(item.textContent ?? "")
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)

                        case .url:
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.url?.absoluteString ?? "")
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .foregroundColor(.blue)
                            }

                        case .image:
                            if let thumbnail = item.thumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(8)
                            }

                        case .file:
                            Text(item.fileName ?? String(localized: "item.file"))
                                .font(.body)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // メタ情報
                    HStack {
                        Image(systemName: typeIcon)
                            .foregroundColor(.secondary)
                        Text(item.timestamp.formatted(.dateTime.year().month().day().hour().minute().locale(Locale.current)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("detail.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("button.close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            onToggleFavorite()
                        } label: {
                            Image(systemName: item.isFavorite ? "star.fill" : "star")
                                .foregroundColor(item.isFavorite ? .yellow : .gray)
                        }
                        Button {
                            onCopy()
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copied = false
                            }
                        } label: {
                            Label(copied ? String(localized: "copy.done") : String(localized: "copy.action"),
                                  systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                        .tint(copied ? .green : .blue)
                    }
                }
            }
        }
    }

    private var typeIcon: String {
        switch item.type {
        case .text: return "doc.text"
        case .url: return "link"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}

// MARK: - Category Filter Bar

struct CategoryFilterBar: View {
    let selectedCategory: ItemCategory?
    let onSelect: (ItemCategory?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    label: String(localized: "category.all"),
                    icon: "tray.2",
                    isSelected: selectedCategory == nil
                ) { onSelect(nil) }

                ForEach(ItemCategory.allCases, id: \.self) { cat in
                    CategoryChip(
                        label: cat.displayName,
                        icon: cat.systemImageName,
                        isSelected: selectedCategory == cat
                    ) { onSelect(selectedCategory == cat ? nil : cat) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}

struct CategoryChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
