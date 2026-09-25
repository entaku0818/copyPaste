# ClipKit

バックグラウンドでもクリップボードを監視し、コピーした内容を自動的に保存するiOSアプリ（PiPモードでバックグラウンド制限を回避）。

## Setup

clone 直後は `ios/copyPaste/Config/` に xcconfig が無いので、先にテンプレートからコピーする。

```bash
cd ios/copyPaste/Config
cp Debug.xcconfig.template Debug.xcconfig      # AdMobのテストIDが入っているのでそのまま使える
cp Release.xcconfig.template Release.xcconfig  # 本番の広告ユニットIDは各自で埋める
```

実体の xcconfig は `.gitignore` 済み（本番の広告ユニットIDが入るため）。
コピーせずにビルドすると広告IDが空のまま通ってしまい、広告が出ないだけで気づきにくい。

## Common Commands

- SwiftLint: `swiftlint lint`
- iOS build/test: `xcodebuild test -project ios/copyPaste.xcodeproj -scheme ClipKit -destination "id=<SIMULATOR_UDID>" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
  - iOS の build/test は `.github/workflows/ios-ci.yml` が GitHub Actions の **self-hosted runner**（entaku の Mac・labels `self-hosted, macOS, xcode27`）で push / PR ごとに実行する（Xcode Cloud は廃止）。GitHub-hosted の macOS ランナー（課金）は使わない＝self-hosted のみ可。`.github/workflows/ci.yml` は ubuntu 上で SwiftLint と Functions ビルドを実行する
  - CI は gitignore 済みの xcconfig をテンプレートから、`GoogleService-Info.plist` をダミー値で生成し、専用シミュレータ `CI-copyPaste`（iOS 27.0）で Debug 構成の build/test を回す。本番の秘密情報は CI に置かない
- Functions lint: `cd functions && npm run lint`
- Functions build (tsc): `cd functions && npm run build`

---

## ループ運用（Loop Engineering）

このリポジトリは memo リポジトリのプロダクトループ（企画→開発→リリース→効果測定→再企画）の対象。
ここで働くエージェントは以下の規律に従う。

### 起点
- 実装するのは**ユーザーが起票した issue、または `loop-go` ラベル付き issue のみ**。勝手に仕事を選ばない
- 提案がある場合は実装せず、issue コメントか報告として出す

### ハーネス（検証ゲート）
- 実装は build / test / lint が緑になるまで自己修正する（コマンド: `swiftlint lint` / `xcodebuild test -project ios/copyPaste.xcodeproj -scheme ClipKit -destination "id=<SIMULATOR_UDID>" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""` / `cd functions && npm run lint && npm run build`）
- **緑でない変更を main に入れない**。5回で緑にならなければブランチに残して報告
- 完了報告には実行した検証コマンドと実出力を含める（「たぶん動く」は完了ではない）
- iOS build/test の CI ゲートは `ios-ci.yml`（self-hosted runner）。ただし runner は entaku の Mac なので、Mac がオフラインだとジョブが待機したままになる。マージ前にローカルで `xcodebuild test` を回す自己修正ループは引き続き省略しない

### エスカレーション（諦め方の設計）
- 同一 issue に2回挑戦して解けない → `loop-attempted` ラベルを付けて人間へ
- スコープが当初依頼から拡大しそう → 黙って続けず「続けると+N時間 / 切り出すと今すぐ完了」の2択を提示
- 製品挙動の判断（仕様の分かれ道）に当たった → 勝手に決めず、選択肢と推奨を添えて人間へ

### タイムボックス
- 軽微修正30分・機能実装2時間が目安。超える見込みなら途中で現状報告し分割を提案する
- 深い修理（テストスイート全体・インフラ）は issue 化して夜間ループに回すのがデフォルト

### 記録（Persistence）
- 非自明な発見・設計判断は issue かコミットメッセージに残す（次のエージェントの Discovery 入力になる）
- 機能リリース時は対応する提案の「答え合わせキー」をリリースノートに含める（リリース+7日で memo のループが KPI 答え合わせをする）
