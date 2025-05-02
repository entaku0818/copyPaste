# コピーした内容の履歴管理と一覧表示（TCA実装）

## 機能要件
- コピーした内容を時系列で一覧表示する
- 各コピー内容に対して以下の情報を表示
  - コピーした日時
  - プレビュー（テキストの場合は内容、画像の場合はサムネイル）
  
## UI要件
- リスト形式で表示
- 最新のコピー内容が上に表示される
- スワイプで削除可能
- タップで詳細表示
- 詳細画面からワンタップでペースト可能

## 技術要件
### TCA（The Composable Architecture）による実装
- State
  - `[ClipboardItem]` 型で履歴を管理
  - `ClipboardItem` は日時とコンテンツを保持
- Action
  - `addItem(ClipboardItem)`
  - `removeItem(IndexSet)`
  - `clearAll`
  - `pasteItem(ClipboardItem)`
- Reducer
  - 各Actionに対応する状態更新ロジック
  - 履歴の保持件数制限（デフォルト100件）の実装
- Effect
  - クリップボードの監視
  - ペースト操作の実行

## テスト要件
- Reducerのテスト
  - 項目追加
  - 項目削除
  - 全件削除
  - 件数制限
- Effectのテスト
  - クリップボード操作 