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
    private var heightConstraint: NSLayoutConstraint?
    private var layoutCallCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Extension 起動を最初に記録（これが出ない場合はExtensionが起動していない）
        KeyboardLogger.log(.launch, "KeyboardViewController.viewDidLoad - Extension起動成功")

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
        layoutCallCount += 1
        KeyboardLogger.log(
            .loadDone,
            "viewWillLayoutSubviews \(layoutCallCount)回目, 制約数: \(view.constraints.count)件"
        )

        // 既存の heightConstraint があれば削除してから再追加（制約の積み重なりを防ぐ）
        guard let v = view else { return }
        if let existing = heightConstraint {
            v.removeConstraint(existing)
        }
        let constraint = NSLayoutConstraint(
            item: v,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: 300
        )
        v.addConstraint(constraint)
        heightConstraint = constraint
    }
}

/// キーボードのSwiftUIビュー
struct ClipboardKeyboardView: View {
    let textDocumentProxy: UITextDocumentProxy
    let switchToNextKeyboard: () -> Void

    @State private var clipboardItems: [ClipboardItem] = []
    @State private var isLoading = true
    @State private var isProUser = false

    var body: some View {
        VStack(spacing: 0) {
            // クリップボード履歴表示エリア
            if isProUser {
                clipboardHistorySection
            } else {
                proPlaceholderSection
            }

            // キーボード切り替えボタン
            keyboardControlsSection
        }
        .background(Color(UIColor.systemBackground))
        .task {
            KeyboardLogger.log(.launch, "ClipboardKeyboardView表示")
            checkProStatus()
            if isProUser {
                await loadClipboardHistory()
            } else {
                isLoading = false
                KeyboardLogger.log(.proCheck, "非Proユーザー - 履歴読込スキップ")
            }
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

    // MARK: - Pro Placeholder Section

    private var proPlaceholderSection: some View {
        HStack {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Pro機能")
                    .font(.caption)
                    .fontWeight(.bold)

                Text("キーボードはPro版限定です")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(height: 100)
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Helper Methods

    private func checkProStatus() {
        isProUser = SharedConstants.sharedDefaults?.bool(forKey: SharedConstants.proStatusKey) ?? false
        KeyboardLogger.log(.proCheck, "isProUser=\(isProUser)")
    }

    private func loadClipboardHistory() async {
        KeyboardLogger.log(.loadStart)
        do {
            let items = try await ClipboardStorageManager.shared.load()
            clipboardItems = items
            isLoading = false
            KeyboardLogger.log(.loadDone, "\(items.count)件")
        } catch {
            isLoading = false
            KeyboardLogger.log(.error, "履歴読込失敗: \(error.localizedDescription)")
        }
    }

    private func insertItem(_ item: ClipboardItem) {
        switch item.type {
        case .text:
            if let text = item.textContent {
                KeyboardLogger.log(.paste, "text(\(text.prefix(30)))")
                textDocumentProxy.insertText(text)
            }
        case .url:
            if let url = item.url {
                KeyboardLogger.log(.paste, "url(\(url.host ?? url.absoluteString))")
                textDocumentProxy.insertText(url.absoluteString)
            }
        case .image:
            // 画像は直接挿入できないため、何もしない
            break
        case .file:
            if let fileName = item.fileName {
                KeyboardLogger.log(.paste, "file(\(fileName))")
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
