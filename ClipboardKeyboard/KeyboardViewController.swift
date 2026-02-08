//
//  KeyboardViewController.swift
//  ClipboardKeyboard
//
//  Created by 遠藤拓弥 on 2026/01/27.
//

import UIKit
import SwiftUI

/// クリップボード履歴を表示するカスタムキーボード
class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<ClipboardKeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        // SwiftUIビューをホスティング
        let keyboardView = ClipboardKeyboardView(
            textDocumentProxy: self.textDocumentProxy,
            switchToNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            }
        )

        let hostingController = UIHostingController(rootView: keyboardView)
        hostingController.view.backgroundColor = .clear

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        self.hostingController = hostingController
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // キーボードの高さを設定（履歴表示分を追加）
        let heightConstraint = NSLayoutConstraint(
            item: view!,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: 300 // 履歴表示エリア + キーボード本体
        )
        view.addConstraint(heightConstraint)
    }
}

/// キーボードのSwiftUIビュー
struct ClipboardKeyboardView: View {
    let textDocumentProxy: UITextDocumentProxy
    let switchToNextKeyboard: () -> Void

    @State private var clipboardItems: [ClipboardItem] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // クリップボード履歴表示エリア
            clipboardHistorySection

            // キーボード切り替えボタン
            keyboardControlsSection
        }
        .background(Color(UIColor.systemBackground))
        .task {
            await loadClipboardHistory()
        }
    }

    // MARK: - クリップボード履歴セクション

    private var clipboardHistorySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .frame(width: 100, height: 80)
                } else if clipboardItems.isEmpty {
                    Text("履歴なし")
                        .foregroundStyle(.secondary)
                        .frame(width: 150, height: 80)
                } else {
                    ForEach(clipboardItems.prefix(10)) { item in
                        ClipboardItemCard(item: item) {
                            insertItem(item)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 100)
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - キーボードコントロールセクション

    private var keyboardControlsSection: some View {
        HStack {
            Spacer()

            Button(action: switchToNextKeyboard) {
                Image(systemName: "globe")
                    .font(.system(size: 24))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }

            Spacer().frame(width: 20)
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Helper Methods

    private func loadClipboardHistory() async {
        do {
            let items = try await ClipboardStorageManager.shared.load()
            clipboardItems = items
            isLoading = false
        } catch {
            print("Failed to load clipboard history: \(error)")
            isLoading = false
        }
    }

    private func insertItem(_ item: ClipboardItem) {
        switch item.type {
        case .text:
            if let text = item.textContent {
                textDocumentProxy.insertText(text)
            }
        case .url:
            if let url = item.url {
                textDocumentProxy.insertText(url.absoluteString)
            }
        case .image:
            // 画像は直接挿入できないため、何もしない
            // または、画像のファイル名や説明を挿入することもできる
            break
        case .file:
            if let fileName = item.fileName {
                textDocumentProxy.insertText(fileName)
            }
        }
    }
}

/// クリップボードアイテムのカード表示
struct ClipboardItemCard: View {
    let item: ClipboardItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                // アイテムタイプアイコン
                HStack {
                    itemIcon
                    Spacer()
                }

                // コンテンツプレビュー
                contentPreview
                    .lineLimit(2)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .padding(8)
            .frame(width: 120, height: 80)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var itemIcon: some View {
        Group {
            switch item.type {
            case .text:
                Image(systemName: "doc.text")
                    .foregroundStyle(.blue)
            case .url:
                Image(systemName: "link")
                    .foregroundStyle(.green)
            case .image:
                if let thumbnail = item.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.orange)
                }
            case .file:
                Image(systemName: "doc")
                    .foregroundStyle(.purple)
            }
        }
        .font(.system(size: 16))
    }

    private var contentPreview: some View {
        Group {
            switch item.type {
            case .text:
                Text(item.textContent ?? "")
            case .url:
                if let url = item.url {
                    Text(url.host ?? url.absoluteString)
                } else {
                    Text("")
                }
            case .image:
                Text("画像")
                    .foregroundStyle(.secondary)
            case .file:
                Text(item.fileName ?? "ファイル")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ClipboardKeyboardView(
        textDocumentProxy: PreviewTextDocumentProxy(),
        switchToNextKeyboard: {}
    )
    .frame(height: 300)
}

// プレビュー用のモックプロキシ
class PreviewTextDocumentProxy: NSObject, UITextDocumentProxy {
    var hasText: Bool

    var documentContextBeforeInput: String?
    var documentContextAfterInput: String?
    var selectedText: String?
    var documentInputMode: UITextInputMode?
    var documentIdentifier: UUID = UUID()

    override init() {
        self.hasText = false
        super.init()
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {}
    func setMarkedText(_ markedText: String, selectedRange: NSRange) {}
    func unmarkText() {}
    func insertText(_ text: String) {
        print("Inserted: \(text)")
        hasText = true
    }
    func deleteBackward() {
        hasText = false
    }
}
