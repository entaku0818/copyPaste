# iCloud同期実装

**優先度**: 高
**ステータス**: 未着手
**ラベル**: enhancement, feature, sync

## 概要

複数のデバイス間でクリップボード履歴を同期する機能を実装する。

## 背景・目的

Yoinkの主要機能の一つである「複数デバイス間同期」を実装：
- iPhone、iPad、Mac（別アプリ）間でクリップボード履歴を共有
- どのデバイスでコピーしても、すべてのデバイスで履歴を確認可能
- シームレスなマルチデバイス体験
- ユーザーの生産性向上

## 機能要件

### 同期機能
- [ ] iCloud経由でのデータ同期
- [ ] リアルタイムまたは準リアルタイム同期
- [ ] 競合解決メカニズム
- [ ] オフライン動作のサポート
- [ ] 同期ON/OFF設定

### データ管理
- [ ] 最大100件の履歴を同期
- [ ] デバイス間でのユニークID管理
- [ ] タイムスタンプベースのマージ
- [ ] 削除の同期

### UI/UX
- [ ] 同期状態の表示
- [ ] 同期エラーの通知
- [ ] 手動同期のトリガー
- [ ] 初回同期の説明

## 技術的な実装

### 1. CloudKitの設定

**Capabilities追加**
```
- iCloud
  - CloudKit
  - Key-Value Storage
```

**Container設定**
```swift
// iCloud.com.yourcompany.copyPaste
let container = CKContainer(identifier: "iCloud.com.copyPaste")
```

### 2. データモデルの定義

```swift
// ClipboardItem.swift
import Foundation
import CloudKit

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    var deviceID: String
    var isDeleted: Bool = false

    // CloudKit Record
    static let recordType = "ClipboardItem"

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType)
        record["id"] = id.uuidString
        record["content"] = content
        record["timestamp"] = timestamp
        record["deviceID"] = deviceID
        record["isDeleted"] = isDeleted ? 1 : 0
        return record
    }

    static func fromRecord(_ record: CKRecord) -> ClipboardItem? {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let content = record["content"] as? String,
              let timestamp = record["timestamp"] as? Date,
              let deviceID = record["deviceID"] as? String else {
            return nil
        }

        let isDeleted = (record["isDeleted"] as? Int) == 1

        return ClipboardItem(
            id: id,
            content: content,
            timestamp: timestamp,
            deviceID: deviceID,
            isDeleted: isDeleted
        )
    }
}
```

### 3. CloudKit Managerの実装

```swift
// CloudKitManager.swift
import CloudKit
import OSLog

class CloudKitManager: ObservableObject {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let logger = Logger(subsystem: "com.copyPaste", category: "CloudKit")

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?

    init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase

        setupSubscriptions()
    }

    // MARK: - Upload

    func saveItem(_ item: ClipboardItem) async throws {
        let record = item.toRecord()

        do {
            _ = try await privateDatabase.save(record)
            logger.info("Saved item to CloudKit: \(item.id)")
        } catch {
            logger.error("Failed to save item: \(error.localizedDescription)")
            throw error
        }
    }

    func deleteItem(_ item: ClipboardItem) async throws {
        // Soft delete
        var deletedItem = item
        deletedItem.isDeleted = true

        try await saveItem(deletedItem)
    }

    // MARK: - Download

    func fetchAllItems() async throws -> [ClipboardItem] {
        let query = CKQuery(
            recordType: ClipboardItem.recordType,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let result = try await privateDatabase.records(matching: query)
            let items = result.matchResults.compactMap { _, result in
                try? result.get()
            }.compactMap { record in
                ClipboardItem.fromRecord(record)
            }.filter { !$0.isDeleted }

            logger.info("Fetched \(items.count) items from CloudKit")
            return items
        } catch {
            logger.error("Failed to fetch items: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchChanges(since changeToken: CKServerChangeToken?) async throws -> ([ClipboardItem], CKServerChangeToken?) {
        let zoneID = CKRecordZone.default().zoneID

        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = changeToken

        var changedItems: [ClipboardItem] = []
        var newChangeToken: CKServerChangeToken?

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: configuration]
        )

        operation.recordWasChangedBlock = { recordID, result in
            if case .success(let record) = result,
               let item = ClipboardItem.fromRecord(record) {
                changedItems.append(item)
            }
        }

        operation.recordZoneFetchResultBlock = { zoneID, result in
            if case .success(let serverChangeToken) = result {
                newChangeToken = serverChangeToken.changeToken
            }
        }

        try await privateDatabase.add(operation)

        return (changedItems, newChangeToken)
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() {
        Task {
            let subscription = CKQuerySubscription(
                recordType: ClipboardItem.recordType,
                predicate: NSPredicate(value: true),
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo

            do {
                try await privateDatabase.save(subscription)
                logger.info("Subscription created successfully")
            } catch {
                logger.error("Failed to create subscription: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Sync

    func syncNow() async throws {
        guard !isSyncing else { return }

        await MainActor.run { isSyncing = true }
        defer { Task { await MainActor.run { isSyncing = false } } }

        logger.info("Starting sync...")

        // ローカルの未同期アイテムをアップロード
        // ...

        // リモートの変更をダウンロード
        let items = try await fetchAllItems()

        // ローカルとマージ
        // ...

        await MainActor.run {
            lastSyncDate = Date()
        }

        logger.info("Sync completed")
    }
}
```

### 4. TCAへの統合

```swift
// ClipboardHistoryFeature.swift
enum Action {
    // 既存のアクション
    // ...

    // 同期関連
    case syncStarted
    case syncCompleted([ClipboardItem])
    case syncFailed(Error)
    case enableSync(Bool)
}

case .syncStarted:
    state.isSyncing = true
    return .run { send in
        do {
            try await cloudKitManager.syncNow()
            let items = try await cloudKitManager.fetchAllItems()
            await send(.syncCompleted(items))
        } catch {
            await send(.syncFailed(error))
        }
    }

case let .syncCompleted(remoteItems):
    state.isSyncing = false
    // ローカルアイテムとリモートアイテムをマージ
    state.items = mergeItems(local: state.items, remote: remoteItems)
    return .none
```

### 5. 競合解決

```swift
func mergeItems(local: [ClipboardItem], remote: [ClipboardItem]) -> [ClipboardItem] {
    var merged: [UUID: ClipboardItem] = [:]

    // ローカルアイテムを追加
    for item in local {
        merged[item.id] = item
    }

    // リモートアイテムをマージ（新しいタイムスタンプを優先）
    for remoteItem in remote {
        if let localItem = merged[remoteItem.id] {
            // 同じIDが存在する場合、タイムスタンプで判断
            if remoteItem.timestamp > localItem.timestamp {
                merged[remoteItem.id] = remoteItem
            }
        } else {
            // 新しいアイテム
            merged[remoteItem.id] = remoteItem
        }
    }

    // 削除されたアイテムを除外
    return Array(merged.values)
        .filter { !$0.isDeleted }
        .sorted { $0.timestamp > $1.timestamp }
}
```

## 技術的な考慮事項

### iCloudアカウント状態
- ユーザーがiCloudにサインインしていない場合の処理
- ストレージ容量不足の処理
- ネットワーク接続がない場合の処理

### データ量制限
- CloudKitの無料枠制限に注意
- 大量のアイテムの効率的な同期
- 差分同期の実装

### セキュリティ
- CloudKitはデフォルトで暗号化
- 個人情報の取り扱いに注意
- プライバシーポリシーの更新

### パフォーマンス
- バッチ処理での同期
- バックグラウンドでの同期
- ユーザー体験を損なわない

## UI/UX

### 設定画面
```swift
Section("同期") {
    Toggle("iCloud同期", isOn: $store.isSyncEnabled)

    if store.isSyncEnabled {
        HStack {
            Text("最終同期")
            Spacer()
            if let lastSync = store.lastSyncDate {
                Text(lastSync, style: .relative)
                    .foregroundColor(.secondary)
            } else {
                Text("未同期")
                    .foregroundColor(.secondary)
            }
        }

        Button("今すぐ同期") {
            store.send(.syncStarted)
        }
        .disabled(store.isSyncing)
    }
}
```

### 同期インジケーター
- ツールバーに同期状態アイコン
- 同期中のプログレス表示
- エラー時の警告表示

## テスト項目

- [ ] 初回同期（ローカル→クラウド）
- [ ] 定期同期
- [ ] 手動同期
- [ ] 複数デバイスからの同期
- [ ] 競合解決
- [ ] 削除の同期
- [ ] オフライン動作
- [ ] iCloudアカウント未サインイン
- [ ] ネットワークエラー時
- [ ] 大量データの同期
- [ ] バッテリー消費

## 参考資料

- [Apple Developer - CloudKit](https://developer.apple.com/documentation/cloudkit)
- [CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2021/10086/)
- [Syncing a Core Data Store with CloudKit](https://developer.apple.com/documentation/coredata/synchronizing_a_local_store_to_the_cloud)
- [CloudKit Console](https://icloud.developer.apple.com/)

## 依存関係

- なし（独立して実装可能）

## 推定工数

- CloudKit設定: 0.5日
- データモデル＆マネージャー実装: 2日
- TCA統合: 1日
- UI実装: 1日
- 競合解決ロジック: 1日
- テスト: 1日
- 合計: 6.5日
