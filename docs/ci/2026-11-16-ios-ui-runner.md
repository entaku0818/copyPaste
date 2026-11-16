# ClipKit iOS UI runner 起動クラッシュ調査（2026-11-16）

## 対象と状態

- 依頼正本: `/Users/entaku/repository/memo/orchestration/tasks/2026-11-16-clipkit-ios-ci.md`。
- 開始点: `main` / `f40ac423ee1327d395011cc4edf594ccc217d040`、作業ツリーclean。
- 作業ブランチ: `fix/ios-ui-runner-bootstrap`。Android試作・App Store公開は対象外。
- 修正コードのローカル全テスト・実iOS CIが成功。全53言語×2外観×3向きの318構成を完走した。

## 原因の直接根拠

対象は [iOS CI run 43669522728](https://github.com/entaku0818/copyPaste/actions/runs/43669522728)、attempt 2、job `132679187396`。GitHub公式APIで最新attemptとログを取得した。元runもXcode 27.1 (`27A9275`)、runner `entaku-mac-copyPaste`。

- build成功後、XCTest単体テスト279件（既存skip 1件、失敗0）とSwift Testing 1件が成功。
- UI runner PID `82390` はUIテストケース開始前、suite構築中に終了。`Early unexpected exit, operation never finished bootstrapping`。
- artifact `14144760747`（`TestResults-43669522728`、ZIP SHA-256 `5f2dddaa5a6471d74ab1e469da3f44933e4a53a18476d19742b192bec443773f`）のxcresultから診断をexportした。
- 同artifact内 `ClipKitUITests-Runner-2026-11-15-120857.ips` は同じPID、incident `CAD476FA-6F18-4259-915A-A6A8501EEDE3`、`EXC_BREAKPOINT / SIGTRAP`、main thread。

クラッシュスタック先頭:

```text
-[__NSArrayM insertObject:atIndex:].cold.3
-[XCTVariationOptions variations]
__89+[XCTestSuite _resolveTestSuiteByTestInvocationsInClass:filteringToTestIdentifiersToRun:]_block_invoke.39
+[XCTestSuite _resolveTestSuiteByTestInvocationsInClass:filteringToTestIdentifiersToRun:]
+[XCTestSuite suitesForBundlesIncludingEmptySuites:]
```

UI runner session logではAccessibilityの初期化は完了し、`Loading test suite...` へ進んでいる。アプリのlocalizationsには全53言語が渡っている。重複Accessibilityクラスの警告、`invalidDigitCount` は観測したが、クラッシュ箇所と一致しないため原因とは断定しない。既に修正済みのXcodeパスも今回の原因ではない。

## 仮説と確認結果

`runsForEachTargetApplicationUIConfiguration = true` によりXCTestが言語・外観・向きの構成を自動生成する際、複数軸の直積を誤って倍増させることが原因と判断した。

Xcode 27.1 (`27A9275`) に同梱されたXCTestCoreを一時診断プログラムから動的に読み、`XCTVariationOptions.initWithInputs:` と `variations` を少数の候補で実行した。同じ専用iOS 27.0 Simulator上で、向き3件、外観2件を固定すると次の実出力を得た（このprivate APIは調査専用。製品・テスト修正には使用しない）。

```text
1 inputs -> 6 variations
2 inputs -> 12 variations
3 inputs -> 24 variations
4 inputs -> 48 variations
5 inputs -> 96 variations
6 inputs -> 192 variations
7 inputs -> 384 variations
8 inputs -> 768 variations
```

本来の3言語なら18構成、8言語なら48構成になるべきところが倍増する。再現はFoundationとObjective-C runtimeを使い、`dlopen` した同梱XCTestCoreの `XCTVariationOptions` に `@{@"language": values, @"orientation": @[@1,@2,@3], @"appearance": @[@"light",@"dark"]}` を渡した。候補数は最大8に制限し、製品コード・XCTest frameworkは変更していない。単一軸だけなら1〜8候補は1〜8構成で正常だった。disassemblyでも、追加候補ごとに既に増やした配列全体をcopyして追加する処理を確認した。辞書の軸順序によって増加量が変わり得る。53言語の元処理を再実行してホストのメモリを圧迫することは避け、元CIの直接証拠と小規模再現を組み合わせた。

[AppleのAPI説明](https://developer.apple.com/documentation/xctest/xctestcase/runsforeachtargetapplicationuiconfiguration)でも、このフラグは言語・外観・向きの組み合わせを自動生成する指定とされている。Apple内部の正式な不具合番号・修正版は未確認。

## 差分

- `copyPasteUITestsLaunchTests.swift`: 自動展開を明示的な反復に置換。既存の `testLaunch`、`testExample`、`testLaunchPerformance` と広告E2E 3件は維持。全53言語、light/dark、iPhoneのportrait/landscapeLeft/landscapeRightを実行し、各構成でアプリwindowとスクリーンショットを確認する（318構成）。iPadではportraitUpsideDownも追加する。言語・外観ごとに起動し、各向きへ回転する。終了時に端末の外観・向きを復元する。
- `LaunchTestLocalizations.json` と `scripts/validate_ui_test_localizations.py`: アプリの `.lproj` 全53言語とfixtureを照合。不足・重複を失敗として検知。新しい言語を追加したら `--write` で更新してレビューする。
- `ios-ci.yml`: 言語照合をbuild前に実行。成功時もxcresultを7日間保存して、UIテスト実行の証拠を確認可能にした。self-hosted runner、iOS 27.0、単体テスト・UIテストの対象は維持。
- `project.pbxproj`: SimulatorでCrashlyticsシンボル送信フェーズを終了する。実機の送信処理は維持。ローカルの自動承認レビューが外部シンボル送信を拒否したため、安全な代替として追加した。テストやチェックのskipではない。

テスト削除、XCTSkip追加、continue-on-error、成功扱いへの終了コード変換、runnerの有料サービスへの移行はしていない。

## ローカル検証

CIと同じテンプレートxcconfigとダミーGoogleService-Info.plistを用いる隔離ソースを `/private/tmp/clipkit-ios-ci-20261116/source` に展開し、個人設定や本番Firebase情報を使わずに検証した。専用Simulator `ClipKit-UIRunner-20261116` (`62916E66-5BE6-4267-A517-9717785A0EA7`、iPhone 17 Pro / iOS 27.0) を作成した。他repoの端末・runnerは停止していない。

- `xcodebuild -list -project ios/copyPaste.xcodeproj`: ClipKit schemeと両テストtargetを確認。
- `xcodebuild build-for-testing ... -configuration Debug -destination id=62916E66-5BE6-4267-A517-9717785A0EA7 ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=''`: `** TEST BUILD SUCCEEDED **`。修正後もbuild成功。
- `xcodebuild test-without-building`（以下の完全コマンド）: exit 0、`** TEST EXECUTE SUCCEEDED **`。XCTest単体279件（既存skip 1、失敗0）、Swift Testing 1件成功。UI 6件（既存広告E2E skip 3、実行3件成功、失敗0）。`testLaunch` は全318構成を完走、1388.790秒。全テスト操作は1467.717秒。

実行コマンド（隔離ソース、依存キャッシュ再利用）:

```sh
xcodebuild build-for-testing \
  -project /private/tmp/clipkit-ios-ci-20261116/source/ios/copyPaste.xcodeproj \
  -scheme ClipKit -configuration Debug \
  -destination id=62916E66-5BE6-4267-A517-9717785A0EA7 \
  -derivedDataPath /private/tmp/clipkit-ios-ci-20261116/DerivedData \
  -clonedSourcePackagesDirPath /Users/entaku/Library/Developer/Xcode/DerivedData/copyPaste-hbbdkzjdefqnqyesdpeltkrdbypw/SourcePackages \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=''

xcodebuild test-without-building \
  -xctestrun /private/tmp/clipkit-ios-ci-20261116/DerivedData/Build/Products/ClipKit_ClipKit_iphonesimulator27.1-arm64.xctestrun \
  -destination id=62916E66-5BE6-4267-A517-9717785A0EA7 \
  -resultBundlePath /private/tmp/clipkit-ios-ci-20261116/local-fixed.xcresult \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=''
```

- `python3 scripts/validate_ui_test_localizations.py`: `UI launch matrix covers all 53 app localizations.`
- 言語照合の一時fixture検証: 言語不足exit 1、重複exit 1、全言語exit 0。
- `swiftlint lint --quiet --no-cache`: exit 0（既存warningあり、変更したUIテストにwarningなし）。通常実行はsandbox外キャッシュ書込権限で失敗したため、キャッシュなしで実行。
- `cd functions && npm run lint && npm run build`: 両方exit 0。
- xcresult summary: `Passed`、total 286 / passed 282 / failed 0 / skipped 4。活動ツリーを53言語×2外観×3向きの直積と照合し、318活動・318個の画像attachment UUIDが一致（欠落・重複0）。日本語のportrait/landscape画像を抜き取り確認。
- `git diff --check`: 成功。
- 隔離ソースのtracked iOSファイル335件を `git show 3a3a83e:<path>` の内容と比較し、全件一致。ローカル検証とremoteの修正コードが同一であることを確認。
- skipの既存条件: 単体 `TrialPaywallSnapshotTests.testSnapshotTrialPaywall` は目視用環境変数が未指定の場合にskip。UI `AdPresentationE2ETests` 3件は `CLIPKIT_AD_E2E=1` が未指定の場合にskip。今回これらの条件は変更していない。元runはUI suite構築前に落ちていたため、広告E2Eの既存skipは表面化していなかった。

初回隔離buildは `-clonedSourcePackagesDirPath` によってCrashlyticsスクリプトの固定依存パスが存在せず失敗した。これはローカル準備の問題で、元CIのrunner crashとは別。次のbuildは外部送信の自動承認レビューで拒否された。Simulatorの送信不要化を適用したbuildで解消した。ローカル・実CIの両buildログで `Simulator build: Crashlytics symbol upload is not required.` を確認した。

## Commit

- `cc6f58f`: `build(ios): avoid Crashlytics uploads for simulator builds`
- `3887a06`: `fix(ios): enumerate UI launch configurations without XCTest expansion`
- `3a3a83e5921a147d3b25826d5426d1ac71c7f0f4`: `ci(ios): verify launch locales and retain successful test evidence`
- 本報告のみを保存する最終commitは `[skip ci]` を使用する。修正コードとworkflowは上記の成功した `3a3a83e` と同一。今回の修正の検証を省略したものではなく、CI成功後の記録追記による再実行を抑制する。

## Remote

- push先: `origin` / `git@github.com:entaku0818/copyPaste.git`、`fix/ios-ui-runner-bootstrap`。
- 修正コードの通常push成功。`git ls-remote origin refs/heads/fix/ios-ui-runner-bootstrap` が `3a3a83e5921a147d3b25826d5426d1ac71c7f0f4` と一致。
- 最終記録commitとの差分は本報告1ファイルのみ。iOS / scripts / workflow / Functionsに追加差分なし。
- mainは変更・mergeしていない。

## 実CI

- 修正後run: [43816518951](https://github.com/entaku0818/copyPaste/actions/runs/43816518951)、attempt 1、push起動、head `3a3a83e5921a147d3b25826d5426d1ac71c7f0f4`。runner `entaku-mac-copyPaste`、job `133129697831`。build・test・artifact upload・cleanupがすべて成功。GitHub公式APIでもrun `completed / success` を確認。
- XCTest単体279件（既存skip 1、失敗0）、Swift Testing 1件成功。UI 6件（広告E2Eの既存skip 3、実行3件成功、失敗0）。
- `Launch matrix completed: 318 configurations; 53 languages x 2 appearances x 3 orientations`。`testLaunch` は1151.271秒で成功、`** TEST EXECUTE SUCCEEDED **`。
- 成功artifact: [TestResults-43816518951 / 14203309791](https://github.com/entaku0818/copyPaste/actions/runs/43816518951/artifacts/14203309791)、107,220,197 bytes、ZIP SHA-256 `e52ea1296e4357a9f02b686c02dfb166caef229cf8492ffcb32797244c905f0f`、保存期限2026-11-23。公式成果物をダウンロードし、xcresult summary `Passed`、total 286 / passed 282 / failed 0 / skipped 4 を確認。
- CI artifactの活動ツリーも53言語×2外観×3向きの直積と照合し、318種類の活動と318個の画像attachment UUIDが一致（欠落・重複0）。ローカルと同じ全構成を実行したことを確認した。

## 残課題・動作検証の範囲

- UI runnerクラッシュの復旧はローカル・実CIで確認済み。追加承認待ちはない。
- 今回作成したローカル専用Simulatorは完了後shutdownし、一時DerivedDataを削除。元の専用CI端末・他repoのrunner・共有SPMキャッシュは削除していない。
- iPadの追加向きはコードに対応するが、今回のCI端末はiPhone。iPad実行、実機、リリースbuild、App Store公開は今回未実施。
- UI起動検証の全言語・外観・向きの実行はローカライズ文章の意味や全機能の操作を保証しない。
- 抜き取り確認した日本語landscapeの `app.screenshot()` 画像には切れと黒領域がある。アプリwindowの存在・runnerの完走は確認済みだが、レイアウトとキャプチャ範囲のどちらに由来するかは未切り分け。今回のUI合格は起動・window存在・構成実行の範囲であり、全画面の視覚的正常性を合格としたものではない。別の画像品質/横画面確認課題として残す。
