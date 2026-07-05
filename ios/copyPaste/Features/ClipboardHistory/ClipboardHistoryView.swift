import SwiftUI
import ComposableArchitecture

struct ClipboardHistoryView: View {
    let store: StoreOf<ClipboardHistoryFeature>
    @State private var selectedItem: ClipboardItem?

    var body: some View {
        List {
            // 検索結果件数
            if !store.searchText.isEmpty {
                HStack {
                    Text(String(format: String(localized: "search.results %lld"), Int64(store.filteredItems.count)))
                        .font(ClipKitFont.meta)
                        .foregroundColor(ClipKitColor.textSecondary)
                    Spacer()
                    Button("search.clear") {
                        store.send(.updateSearchText(""))
                    }
                    .font(ClipKitFont.meta)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: ClipKitSpacing.screenPadding, bottom: 8, trailing: ClipKitSpacing.screenPadding))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            ForEach(Array(store.filteredItems.enumerated()), id: \.element.id) { index, item in
                ClipboardItemRow(item: item)
                    .clipKitCardRow(.at(index, count: store.filteredItems.count))
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
                        .tint(item.isFavorite ? .gray : ClipKitColor.favorite)
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
                Button {
                    store.send(.showPaywall)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(ClipKitColor.crown)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("upgrade.title")
                                .font(ClipKitFont.rowTitleEmphasized)
                                .foregroundColor(ClipKitColor.textPrimary)
                            Text("upgrade.description")
                                .font(ClipKitFont.meta)
                                .foregroundColor(ClipKitColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ClipKitColor.textTertiary)
                    }
                }
                .clipKitCardRow(.single)
                .padding(.top, 4)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ClipKitColor.canvas)
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
    let isProUser: Bool
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onCopyTransformed: (String, TextTransform) -> Void
    let onPaywallDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var transformCopied = false
    @State private var showTransformPaywall = false

    // 変換対象のテキスト（テキスト・URLアイテムのみ）
    private var transformSourceText: String? {
        switch item.type {
        case .text: return item.textContent
        case .url: return item.url?.absoluteString
        case .image, .file: return nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // コンテンツ本文
                    Group {
                        switch item.type {
                        case .text:
                            Text(item.textContent ?? "")
                                .font(.system(size: 16))
                                .foregroundColor(ClipKitColor.textPrimary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)

                        case .url:
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.url?.absoluteString ?? "")
                                    .font(.system(size: 16))
                                    .textSelection(.enabled)
                                    .foregroundColor(ClipKitColor.indigo)
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
                                .font(.system(size: 16))
                                .foregroundColor(ClipKitColor.textPrimary)
                        }
                    }
                    .padding()
                    .lineSpacing(4)
                    .background(ClipKitColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: ClipKitRadius.card, style: .continuous))

                    // メタ情報
                    HStack {
                        Image(systemName: typeIcon)
                            .foregroundColor(ClipKitColor.textTertiary)
                        Text(item.timestamp.formatted(.dateTime.year().month().day().hour().minute().locale(Locale.current)))
                            .font(ClipKitFont.meta)
                            .foregroundColor(ClipKitColor.textTertiary)
                    }

                    // 変換してコピー
                    if let sourceText = transformSourceText {
                        transformMenu(sourceText: sourceText)
                    }
                }
                .padding()
            }
            .background(ClipKitColor.canvas)
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
                                .foregroundColor(item.isFavorite ? ClipKitColor.favorite : .gray)
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
                        .tint(copied ? ClipKitColor.success : ClipKitColor.indigo)
                    }
                }
            }
        }
        .sheet(isPresented: $showTransformPaywall, onDismiss: onPaywallDismiss) {
            PaywallView()
        }
    }

    @ViewBuilder
    private func transformMenu(sourceText: String) -> some View {
        Menu {
            ForEach(TextTransform.allCases, id: \.self) { transform in
                Button {
                    if transform.requiresPro && !isProUser {
                        showTransformPaywall = true
                    } else {
                        onCopyTransformed(transform.apply(to: sourceText), transform)
                        transformCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            transformCopied = false
                        }
                    }
                } label: {
                    Label(
                        transform.displayName,
                        systemImage: transform.requiresPro && !isProUser
                            ? "crown.fill"
                            : transform.systemImageName
                    )
                }
            }
        } label: {
            HStack {
                Image(systemName: transformCopied ? "checkmark" : "wand.and.stars")
                Text(transformCopied ? String(localized: "copy.done") : String(localized: "transform.menu.copy"))
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(ClipKitColor.textTertiary)
            }
            .padding()
            .background(ClipKitColor.card)
            .foregroundColor(transformCopied ? ClipKitColor.success : ClipKitColor.indigo)
            .clipShape(RoundedRectangle(cornerRadius: ClipKitRadius.card, style: .continuous))
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
            .padding(.horizontal, ClipKitSpacing.screenPadding)
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
            .background(isSelected ? ClipKitColor.indigo : ClipKitColor.controlBackground)
            .foregroundStyle(isSelected ? .white : ClipKitColor.textPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
