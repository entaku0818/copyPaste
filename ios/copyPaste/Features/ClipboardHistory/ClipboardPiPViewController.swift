import AVKit
import UIKit
import OSLog

/// PiP ウィンドウに表示するカスタムコンテンツ
final class ClipboardPiPViewController: AVPictureInPictureVideoCallViewController {
    private let logger = Logger(subsystem: "com.clipkit", category: "PiPVC")
    private var tableView: UITableView!
    private var emptyLabel: UILabel!
    private(set) var items: [ClipboardItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 240, height: 210)
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        let header = UIView()
        header.backgroundColor = UIColor.systemGray6
        header.translatesAutoresizingMaskIntoConstraints = false

        let icon = UILabel()
        icon.text = "📋"
        icon.font = .systemFont(ofSize: 12)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "ClipKit"
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let hint = UILabel()
        hint.text = "タップでコピー"
        hint.font = .systemFont(ofSize: 9)
        hint.textColor = .secondaryLabel
        hint.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(icon)
        header.addSubview(title)
        header.addSubview(hint)

        tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .singleLine
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 36
        tableView.backgroundColor = .systemBackground

        emptyLabel = UILabel()
        emptyLabel.text = "履歴なし"
        emptyLabel.font = .systemFont(ofSize: 12)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true

        view.addSubview(header)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 28),

            icon.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 4),
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            hint.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -8),
            hint.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
        ])
    }

    func updateItems(_ newItems: [ClipboardItem]) {
        items = Array(newItems.prefix(5))
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.emptyLabel?.isHidden = !self.items.isEmpty
            self.tableView?.reloadData()
        }
    }
}

// MARK: - UITableViewDataSource / Delegate

extension ClipboardPiPViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let item = items[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.textProperties.font = .systemFont(ofSize: 11)
        config.textProperties.numberOfLines = 2

        switch item.type {
        case .text:
            config.text = item.textContent.map { String($0.prefix(60)) } ?? ""
        case .url:
            config.text = item.url?.absoluteString.prefix(60).description ?? ""
        case .image:
            config.text = "📷 画像"
            if let thumb = item.thumbnail {
                config.image = thumb
                config.imageProperties.maximumSize = CGSize(width: 24, height: 24)
            }
        case .file:
            config.text = "📄 \(item.fileName ?? "ファイル")"
        }

        cell.contentConfiguration = config
        cell.backgroundColor = .systemBackground
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]

        switch item.type {
        case .text:    UIPasteboard.general.string = item.textContent
        case .url:     UIPasteboard.general.url = item.url
        case .image:   UIPasteboard.general.image = item.thumbnail
        case .file:    break
        }
        logger.info("Copied from PiP: \(item.type.rawValue)")

        // コピー完了フィードバック
        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.15) {
                cell.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
            } completion: { _ in
                UIView.animate(withDuration: 0.3) {
                    cell.backgroundColor = .systemBackground
                }
            }
        }
    }
}
