//
//  KeyboardViewController.swift
//  ClipboardKeyboard
//
//  Created by 遠藤拓弥 on 2026/01/27.
//

import UIKit

/// クリップボード履歴を表示するカスタムキーボード
class KeyboardViewController: UIInputViewController {

    // MARK: - UI Parts

    private let contentView = UIView()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let controlBar = UIView()
    private let nextKeyboardButton = UIButton(type: .system)

    // MARK: - State

    private var clipboardItems: [ClipboardItem] = []
    private var isProUser = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardLogger.log(.launch, "KeyboardViewController.viewDidLoad - Extension起動成功")

        checkProStatus()
        setupUI()

        if isProUser {
            loadClipboardHistory()
        }
    }

    // MARK: - Pro Status

    private func checkProStatus() {
        isProUser = SharedConstants.sharedDefaults?.bool(forKey: SharedConstants.proStatusKey) ?? false
        KeyboardLogger.log(.proCheck, "isProUser=\(isProUser)")
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        setupControlBar()
        setupContentArea()
    }

    private func setupControlBar() {
        controlBar.backgroundColor = UIColor.systemBackground
        controlBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlBar)

        NSLayoutConstraint.activate([
            controlBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controlBar.heightAnchor.constraint(equalToConstant: 44),
        ])

        // 地球儀ボタンは複数キーボードがある時のみ表示
        if needsInputModeSwitchKey {
            nextKeyboardButton.setImage(UIImage(systemName: "globe"), for: .normal)
            nextKeyboardButton.tintColor = .label
            nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
            controlBar.addSubview(nextKeyboardButton)

            NSLayoutConstraint.activate([
                nextKeyboardButton.trailingAnchor.constraint(equalTo: controlBar.trailingAnchor, constant: -16),
                nextKeyboardButton.centerYAnchor.constraint(equalTo: controlBar.centerYAnchor),
                nextKeyboardButton.widthAnchor.constraint(equalToConstant: 44),
                nextKeyboardButton.heightAnchor.constraint(equalToConstant: 44),
            ])
        }
    }

    private func setupContentArea() {
        if isProUser {
            setupHistoryView()
        } else {
            setupProPlaceholder()
        }
    }

    // MARK: - Pro: 履歴ビュー

    private func setupHistoryView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delaysContentTouches = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = UIColor.secondarySystemBackground
        view.addSubview(scrollView)

        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: controlBar.topAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 100),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -10),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -12),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -20),
        ])

        // ロード中プレースホルダー
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.startAnimating()
        stackView.addArrangedSubview(loadingIndicator)
    }

    private func refreshHistoryCards() {
        // 既存のカードを削除
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if clipboardItems.isEmpty {
            let label = UILabel()
            label.text = "履歴なし"
            label.textColor = .secondaryLabel
            label.font = .systemFont(ofSize: 14)
            stackView.addArrangedSubview(label)
        } else {
            for item in clipboardItems.prefix(10) {
                let card = makeHistoryCard(item)
                stackView.addArrangedSubview(card)
            }
        }
    }

    private func makeHistoryCard(_ item: ClipboardItem) -> UIView {
        let card = UIButton(type: .system)
        card.backgroundColor = UIColor.systemBackground
        card.layer.cornerRadius = 8
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 2
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: 120),
            card.heightAnchor.constraint(equalToConstant: 80),
        ])

        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.spacing = 4
        vStack.alignment = .leading
        vStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(vStack)
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
        ])

        let iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),
        ])

        let textLabel = UILabel()
        textLabel.font = .systemFont(ofSize: 11)
        textLabel.textColor = .label
        textLabel.numberOfLines = 2
        textLabel.lineBreakMode = .byTruncatingTail

        switch item.type {
        case .text:
            iconImageView.image = UIImage(systemName: "doc.text")
            iconImageView.tintColor = .systemBlue
            textLabel.text = item.textContent ?? ""
        case .url:
            iconImageView.image = UIImage(systemName: "link")
            iconImageView.tintColor = .systemGreen
            textLabel.text = item.url?.host ?? item.url?.absoluteString ?? ""
        case .image:
            iconImageView.image = UIImage(systemName: "photo")
            iconImageView.tintColor = .systemOrange
            textLabel.text = "画像"
        case .file:
            iconImageView.image = UIImage(systemName: "doc")
            iconImageView.tintColor = .systemPurple
            textLabel.text = item.fileName ?? "ファイル"
        }

        vStack.addArrangedSubview(iconImageView)
        vStack.addArrangedSubview(textLabel)

        card.addTarget(self, action: #selector(cardTapped(_:)), for: .touchDown)
        card.accessibilityIdentifier = item.id.uuidString
        return card
    }

    @objc private func cardTapped(_ sender: UIButton) {
        guard let idStr = sender.accessibilityIdentifier,
              let uuid = UUID(uuidString: idStr),
              let item = clipboardItems.first(where: { $0.id == uuid }) else { return }

        // 触覚フィードバック
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // カードを一瞬ハイライト
        UIView.animate(withDuration: 0.08, animations: {
            sender.alpha = 0.4
        }) { _ in
            UIView.animate(withDuration: 0.12) {
                sender.alpha = 1.0
            }
        }

        insertItem(item)
        KeyboardLogger.log(.paste, "\(item.type)")
    }

    // MARK: - Free: Proプレースホルダー

    private func setupProPlaceholder() {
        let container = UIView()
        container.backgroundColor = UIColor.secondarySystemBackground
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: controlBar.topAnchor),
            container.heightAnchor.constraint(equalToConstant: 100),
        ])

        // クラウンアイコン
        let crownImageView = UIImageView(image: UIImage(systemName: "crown.fill"))
        crownImageView.tintColor = .systemYellow
        crownImageView.contentMode = .scaleAspectFit
        crownImageView.translatesAutoresizingMaskIntoConstraints = false

        // メッセージ
        let messageLabel = UILabel()
        messageLabel.text = "ClipKit Proでキーボードから即ペースト"
        messageLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        messageLabel.textColor = .label
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 2
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        // アップグレードボタン
        let upgradeButton = UIButton(type: .system)
        upgradeButton.setTitle("Proにアップグレード", for: .normal)
        upgradeButton.setTitleColor(.white, for: .normal)
        upgradeButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        upgradeButton.backgroundColor = .systemBlue
        upgradeButton.layer.cornerRadius = 8
        upgradeButton.translatesAutoresizingMaskIntoConstraints = false
        upgradeButton.addTarget(self, action: #selector(upgradeButtonTapped), for: .touchUpInside)

        container.addSubview(crownImageView)
        container.addSubview(messageLabel)
        container.addSubview(upgradeButton)

        NSLayoutConstraint.activate([
            crownImageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            crownImageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            crownImageView.widthAnchor.constraint(equalToConstant: 22),
            crownImageView.heightAnchor.constraint(equalToConstant: 22),

            messageLabel.topAnchor.constraint(equalTo: crownImageView.bottomAnchor, constant: 4),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            upgradeButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 6),
            upgradeButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            upgradeButton.widthAnchor.constraint(equalToConstant: 180),
            upgradeButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    @objc private func upgradeButtonTapped() {
        guard let url = URL(string: "clipkit://subscription") else { return }
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let r = responder {
            if r.responds(to: selector) {
                r.perform(selector, with: url)
                break
            }
            responder = r.next
        }
    }

    // MARK: - Clipboard History Load

    private func loadClipboardHistory() {
        Task {
            do {
                let items = try await ClipboardStorageManager.shared.load()
                await MainActor.run {
                    self.clipboardItems = items
                    self.refreshHistoryCards()
                }
            } catch {
                KeyboardLogger.log(.error, "履歴読込失敗: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Insert

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
            break
        case .file:
            if let fileName = item.fileName {
                KeyboardLogger.log(.paste, "file(\(fileName))")
                textDocumentProxy.insertText(fileName)
            }
        }
    }
}
