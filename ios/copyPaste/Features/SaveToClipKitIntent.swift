import AppIntents
import Combine
import Foundation

struct SaveToClipKitIntent: AppIntent {
    static let title = LocalizedStringResource("Save to ClipKit", table: "Shortcuts")
    static let description = IntentDescription(
        LocalizedStringResource("Save shared text or a link to your ClipKit history.", table: "Shortcuts")
    )

    @available(iOS 26.0, *)
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: LocalizedStringResource("Text or link", table: "Shortcuts"),
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    @MainActor
    static let savedItems = PassthroughSubject<(item: ClipboardItem, removedIDs: Set<UUID>), Never>()

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let item = try Self.makeItem(from: text)
        let isPro = SharedConstants.sharedDefaults?.object(forKey: SharedConstants.proStatusKey) as? Bool
        // 購入状態がまだキャッシュされていない起動では履歴を削除しない。
        let limit = isPro == false ? ClipboardHistoryFeature.State.freeHistoryLimit : nil
        let removedIDs: Set<UUID>
        do {
            removedIDs = try await ClipboardStorageManager.shared.saveSharedItem(item, limit: limit)
        } catch {
            throw SaveError.storageUnavailable
        }
        Self.savedItems.send((item, removedIDs))
        return .result(dialog: IntentDialog(LocalizedStringResource("Saved to ClipKit.", table: "Shortcuts")))
    }

    static func makeItem(from input: String) throws -> ClipboardItem {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SaveError.emptyInput }

        if let url = URL(string: trimmed, encodingInvalidCharacters: false),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           let host = url.host, !host.isEmpty {
            var item = ClipboardItem(url: url)
            item.category = .url
            return item
        }
        var item = ClipboardItem(content: input)
        item.category = ClipboardItemAnalyzer.category(for: input)
        return item
    }

    private enum SaveError: LocalizedError {
        case emptyInput
        case storageUnavailable

        var errorDescription: String? {
            switch self {
            case .emptyInput:
                return String(localized: "Share some text or a link to save to ClipKit.", table: "Shortcuts")
            case .storageUnavailable:
                return String(localized: "ClipKit couldn’t save the shared item. Try again.", table: "Shortcuts")
            }
        }
    }
}
