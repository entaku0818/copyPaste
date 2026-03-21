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
                            selectedItem = item
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            store.send(.toggleFavorite(item))
                        } label: {
                            Label(
                                item.isFavorite ? "お気に入り解除" : "お気に入り",
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
                            Label("削除", systemImage: "trash")
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
                                Text("ClipKit Proにアップグレード")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("3日以上前の履歴も検索・閲覧できます")
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
        .navigationTitle("履歴")
        .searchable(
            text: Binding(
                get: { store.searchText },
                set: { store.send(.updateSearchText($0)) }
            ),
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "履歴を検索..."
        )
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
        .safeAreaInset(edge: .bottom) {
            if !store.isProUser {
                BannerAdView()
                    .frame(height: 50)
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
                            Text(item.fileName ?? "ファイル")
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
                        Text(item.timestamp.formatted(.dateTime.year().month().day().hour().minute().locale(Locale(identifier: "ja_JP"))))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
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
                            Label(copied ? "コピー済み" : "コピー",
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
