# copyPaste

📋 [Yoink](https://apps.apple.com/jp/app/yoink-improved-drag-and-drop/id1260915283)風のクリップボード履歴管理iOSアプリ

バックグラウンドでもクリップボードを監視し、コピーした内容を自動的に保存します。Picture-in-Picture（PiP）モードを活用することで、iOS 16以降の制限を回避しています。

## ✨ 主な機能

### 実装済み

- ✅ **バックグラウンドクリップボード監視**
  - PiPモードを使用してバックグラウンドでもクリップボードを監視
  - 自動PiP起動（アプリ起動2.5秒後）
  - リアルタイム状態表示

- ✅ **履歴管理**
  - 最大100件の履歴を自動保存
  - コピー日時の表示
  - スワイプで削除
  - 一括削除機能

- ✅ **TCA（The Composable Architecture）による実装**
  - テスタブルで保守性の高いコード
  - 状態管理の明確化

- ✅ **詳細なログ機能**
  - os.logによる構造化ログ
  - カテゴリ別ログ（PiP, Clipboard）

### 🔜 今後実装予定

- [ ] iCloud同期（複数デバイス間）
- [ ] 共有エクステンション
- [ ] 今日ウィジェット
- [ ] ショートカット/Siri対応
- [ ] 画像のサポート
- [ ] Spotlight検索対応
- [ ] カスタムスニペット機能

## 📱 動作環境

- iOS 17.0以上
- iPhone / iPad
- Xcode 15.0以上（開発環境）
- Swift 5.9以上

## 🚀 使い方

詳細な使い方は[ヘルプドキュメント](docs/HELP.md)を参照してください。

### クイックスタート

1. アプリを起動
2. クリップボードアクセスの許可を承認
3. 自動的にPiPモードに入り、監視が開始されます
4. 他のアプリでテキストをコピーすると自動的に保存されます

### PiPモードについて

PiPモードは、アプリがバックグラウンドでもクリップボードにアクセスできるようにするための仕組みです。小さなビデオウィンドウが画面の隅に表示されますが、これによりiOS 16以降のクリップボード制限を回避しています。

## 🔧 開発環境のセットアップ

1. リポジトリをクローン
```bash
git clone https://github.com/yourusername/copyPaste.git
cd copyPaste
```

2. Xcodeでプロジェクトを開く
```bash
open copyPaste.xcodeproj
```

3. 依存関係の解決
   - Xcodeが自動的にSwift Package Managerの依存関係を解決します
   - 主な依存関係：
     - [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)

4. 実機で実行
   - PiP機能はシミュレーターでは動作しません
   - 実機で実行してください

## 🏗️ プロジェクト構成

```
copyPaste/
├── copyPasteApp.swift          # アプリエントリーポイント
├── ContentView.swift           # メインビュー
├── Features/
│   ├── ClipboardHistory/      # クリップボード履歴機能
│   │   ├── ClipboardHistoryFeature.swift  # TCA Reducer
│   │   ├── ClipboardHistoryView.swift     # UI
│   │   └── ClipboardItem.swift            # データモデル
│   ├── VideoPlayerView.swift  # PiP用ビデオプレイヤー
│   └── PiPManager.swift        # PiP管理（レガシー、使用していない）
├── Resources/
│   └── transparent_with_audio.mp4  # PiP用ビデオファイル
└── Info.plist                  # アプリ設定
```

## 🎯 技術的な特徴

### PiPによるバックグラウンド監視

iOS 16以降、バックグラウンドでのクリップボードアクセスは厳しく制限されています。このアプリは`AVPlayerViewController`を使用してPiPモードに入ることで、アプリを「準アクティブ」状態に保ち、クリップボードへのアクセスを可能にしています。

**実装の要点:**
- AVPlayerViewControllerのPiPサポートを活用
- 音声付き透明ビデオの継続再生
- PiP状態のデリゲート監視
- AVAudioSessionの適切な設定

### TCAアーキテクチャ

The Composable Architectureを使用することで：
- 状態管理の一元化
- 副作用（Effect）の明確な分離
- テストしやすいコード
- 予測可能な状態遷移

## 📝 ドキュメント

- [使い方ガイド](docs/HELP.md)
- [Issue: クリップボード履歴管理](docs/issues/001-clipboard-history.md)
- [Issue: バックグラウンド監視](docs/issues/002-background-monitoring.md)

## 🤝 コントリビューション

プルリクエストを歓迎します！大きな変更の場合は、まずIssueを開いて変更内容を議論してください。

## 📄 ライセンス

MIT License

## 🙏 謝辞

- [Yoink](https://apps.apple.com/jp/app/yoink-improved-drag-and-drop/id1260915283) - インスピレーション元
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) - アーキテクチャフレームワーク

## 📞 サポート

問題が発生した場合は、[Issues](https://github.com/yourusername/copyPaste/issues)で報告してください。
