import SwiftUI
import ComposableArchitecture

/// 定型文（スニペット）の一覧・登録・編集・並び替え画面
struct SnippetsView: View {
    let store: StoreOf<ClipboardHistoryFeature>
    @State private var showAddSheet = false
    @State private var editingSnippet: Snippet?
    @State private var showPaywall = false

    var body: some View {
        Group {
            if store.snippets.isEmpty {
                ContentUnavailableView(
                    "snippets.empty",
                    systemImage: "text.quote",
                    description: Text("snippets.emptyDescription")
                )
            } else {
                List {
                    ForEach(Array(store.snippets.enumerated()), id: \.element.id) { index, snippet in
                        Button {
                            editingSnippet = snippet
                        } label: {
                            HStack(spacing: ClipKitSpacing.rowGap) {
                                IconBadge(systemImage: "text.quote", colors: ClipKitColor.badgeIndigo, size: 40)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(snippet.displayTitle)
                                        .font(ClipKitFont.rowTitleEmphasized)
                                        .foregroundColor(ClipKitColor.textPrimary)
                                        .lineLimit(1)
                                    Text(snippet.content)
                                        .font(ClipKitFont.meta)
                                        .foregroundColor(ClipKitColor.textTertiary)
                                        .lineLimit(2)
                                }
                                Spacer()
                            }
                        }
                        .clipKitCardRow(.at(index, count: store.snippets.count))
                    }
                    .onDelete { store.send(.deleteSnippets($0)) }
                    .onMove { store.send(.moveSnippets($0, $1)) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(ClipKitColor.canvas)
            }
        }
        .navigationTitle("snippets.title")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if store.canAddSnippet {
                        showAddSheet = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !store.isProUser {
                Text(String(
                    format: String(localized: "snippets.freeLimit %lld"),
                    Int64(ClipboardHistoryFeature.State.freeSnippetLimit)
                ))
                .font(.caption)
                .foregroundColor(ClipKitColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.regularMaterial)
            }
        }
        .onAppear {
            store.send(.updateProStatus)
            store.send(.loadSnippets)
        }
        .sheet(isPresented: $showAddSheet) {
            SnippetEditorView { title, content in
                store.send(.addSnippet(title: title, content: content))
            }
        }
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditorView(snippet: snippet) { title, content in
                var updated = snippet
                updated.title = title
                updated.content = content
                store.send(.updateSnippet(updated))
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

/// スニペットの新規登録・編集シート
struct SnippetEditorView: View {
    var snippet: Snippet?
    let onSave: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String

    init(snippet: Snippet? = nil, onSave: @escaping (String, String) -> Void) {
        self.snippet = snippet
        self.onSave = onSave
        _title = State(initialValue: snippet?.title ?? "")
        _content = State(initialValue: snippet?.content ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("snippets.titleField") {
                    TextField("snippets.titlePlaceholder", text: $title)
                }
                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                } header: {
                    Text("snippets.contentField")
                } footer: {
                    Text("snippets.placeholderHint")
                }
            }
            .navigationTitle(snippet == nil ? Text("snippets.add") : Text("snippets.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("snippets.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("snippets.save") {
                        onSave(title, content)
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
