# ClipKit Android 標準IME 最小試作の実装・検証

実施日: 2026-11-15 JST。ユーザー承認済みの標準IME方式によるAndroid最小試作。

## 結果

Android標準IMEとして選択したClipKitで、他アプリのテキストコピー→端末内への永続保存→履歴ボタンの実タップ→他アプリの入力欄へ `InputConnection.commitText` を実証した。API 33 / Android 13とAPI 35 / Android 15のエミュレータで統合チェックを実行。別パッケージの検証エディタに加え、API 33の標準設定アプリの検索欄でも一周を確認した。

**次段階の開発は可能。ただし「標準IMEに選択され、サービスが動作している間の収集」が前提であり、24時間漏れなく保存できる保証はできない。** 強制停止・別IME中の中間コピーは失われる。通常の文字入力には別IMEへの切替が必要な最小キーUIであり、常用キーボードの完成度は今回の対象外。

- debug APKはローカル成果物として `docs/android-prototype/artifacts/clipkit-prototype-debug.apk` に保持する。Gitには含めない。再生成先は `android/app/build/outputs/apk/debug/app-debug.apk`。
- SHA-256: `26d1961a045373d3ef2b567ef3b6ff32bc6baa9859a254ceefa59cdad9001714`（[実出力](evidence/apk-sha256.txt)）
- 初期 `git status --short` は空。変更は新規 `android/` と `docs/android-prototype/` のみ。既存iOS・Functions・ストア設定への変更なし。
- ソース・再現スクリプト・必要な検証記録をコミット対象とする。push、ストア公開、新規hooks承認、ブラウザ操作、同期・課金・広告実装は実施していない。個人端末のIME設定は変更していない。検証終了時は両エミュレータの標準IMEが元のGboardであることを照合し、今回起動した両エミュレータを終了した。

## 公開用記録とGit対象

`android/` のソース・Gradle wrapper・再現スクリプトと、本ディレクトリの結果・最終検証記録を管理する。Gradle wrapper JARは再現に必要な起動ツールとして含める。APK/AAB、buildディレクトリ、.gradle、local.properties、IDE・Python等のキャッシュは除外する。APKはローカルに残し、上記ハッシュは今回検証したローカルAPKの識別用とする。

公開用ログではユーザーのホームを `<user-home>`、リポジトリの絶対パスを `<repo>`、JUnitのホスト名を `local-host` に置換し、無関係なAVD名を省略した。試験結果・OS/ツール版・終了状態・試験用文字列は維持している。標準設定アプリのスクリーンショットとUI階層は試験用内容のみであることを確認した。

コミット準備ではアプリ・テスト・再現スクリプトの動作変更は行っていないため、以下の既存ビルド・API 33/35検証結果を採用し、再実行していない。今後も意味のある作業の区切りでこまめにコミットする。

## 実装

| ファイル | 内容 |
|---|---|
| `android/settings.gradle`, `build.gradle`, `gradlew`, `gradle/wrapper/` | iOSから独立したAndroidプロジェクトと固定Gradle wrapper |
| `android/app/src/main/AndroidManifest.xml`, `res/xml/method.xml` | 標準InputMethodService登録、システムだけがbindできるBIND_INPUT_METHOD、有効化・設定画面 |
| `ClipKitIme.java` | ClipboardManagerリスナー、標準IME判定、履歴表示とcommitText、abc・空白・削除・改行・IME切替 |
| `HistoryPolicy.java` | 最大20件、直近3日、完全一致の重複排除、空白だけ・100,000文字超の除外 |
| `HistoryStore.java` | アプリ専用領域 `files/history.json` のAtomicFile保存。保存結果を確認して取得済みclip指紋を永続化 |
| `MainActivity.java` | IME有効化・選択案内、履歴一覧、全削除と確認ダイアログ |
| `res/xml/backup_rules.xml` | クラウドバックアップと端末移行から履歴・取得済み指紋を除外 |
| `android/app/src/test/…/HistoryPolicyTest.java` | 保持上限・重複時刻・期限境界・時計巻戻り・機密・空値・サイズ制限のunit test |
| `android/fixture/` | 独立したコピー元・入力先アプリと、エミュレータ限定の実UI統合テスト |
| `android/scripts/` | 物理端末を拒否し、元のIMEを復元する再現スクリプト |

収集対象は単一itemのテキストのみ。`android.content.extra.IS_SENSITIVE` がtrueのclipは本文を読まず除外する。取得途中に別アプリがclipを差し替える競合に備え、メタデータと取得したclip本体の両方でフラグを確認する。URI・Intentの解決、画像取得、クラウド送信は行わない。アプリにINTERNET権限・Accessibility権限・常駐特権・root要件はない。収集テキストをアプリログへ出力しない。検証ログ中の文字列は試験用文字列のみ。

履歴の貼付けはクリップボードを書き換えない。履歴UIに再コピー機能は設けていない。他アプリによる同文の再コピーも完全一致で重複抑止し、取得時刻を延長しない。最後に取得したclipの時刻と本文SHA-256を保存し、全削除後に同一clipがIME再生成だけで復活するのを防ぐ。期限は保存・履歴読み取り・貼付け時に評価する。3日経過した瞬間のタイマー物理消去は未実装。時計が過去へ戻り未来日付になった記録は除外する。

API 35のエッジ表示でシステムナビゲーションがキーと重なる不具合を検出し、システムバーのInsetsを反映して修正した。

## 環境

[環境コマンドの実出力](evidence/environment.log)。SDK platforms 29〜36、JBR 17.0.14、ADB 36.0.0、Gradle wrapper 8.13、Android Gradle Plugin 8.13.2、compileSdk / targetSdk 36、minSdk 29。

接続実機は初回 `adb devices -l` で0台。既存の利用可能なAVDを起動した。

| AVD | 構成 | 用途 |
|---|---|---|
| Pixel_6_API_33 / emulator-5554 | Android 13、API 33、Google APIs、arm64 | 統合チェック、期限境界、再起動、標準設定アプリ |
| Pixel_7_API_35_Play / emulator-5556 | Android 15、API 35、Google Play、arm64 | 同じ統合チェック、期限境界、再起動 |

初回のサンドボックス内ADB起動は `could not install *smartsocket* listener: Operation not permitted`、Gradleはnative libraryロードで失敗した。通常のツール承認機構でサンドボックス外実行に切り替えて成功した。Android端末内の権限制約を回避したものではない。SDK追加導入・新規hook承認は不要だった。

## ビルド・lint・unit test

```sh
cd android
./gradlew :app:assembleDebug :app:lint :app:testDebugUnitTest \
  :fixture:assembleDebug :fixture:assembleDebugAndroidTest :fixture:lintDebug
```

[最終ビルド実出力](evidence/final-build.log):

```text
BUILD SUCCESSFUL in 1s
120 actionable tasks: 2 executed, 118 up-to-date
```

[最新lintの実出力](evidence/final-lint.log)も保存。初回・中間ビルドおよびwrapper生成の冗長なログはGit対象外とし、最終ビルドとAPI 33/35統合ログを管理する。unit testは[JUnit XML](evidence/unit-tests.xml)で `tests="3" skipped="0" failures="0" errors="0"`。APKは `android/app/build/outputs/apk/debug/app-debug.apk` にも生成される。

lintの警告と制約は [app](evidence/lint-app.txt) / [検証アプリ](evidence/lint-fixture.txt) の実出力参照。エラーは0。試作の単一言語UI、同期永続書込み、使用中Gradleより新しい版の案内等が残る。最新debug lintはapp 0 errors / 3 warnings、検証アプリ 0 errors / 3 warnings。同期書込みは終了直後の永続性を優先した試作判断で、製品化時は書込みキューとUI応答時間の測定が必要。

## 端末での測定

実際のタップはOS標準のUiAutomationによるUIテスト。テストのshell / run-asは導入・検証・保存ファイル検査に限る。製品の保存・入力経路には使わない。試験用ファイル注入は期限境界の検証だけで、自動保存の実証に注入は使っていない。

| ケース | API 33 / API 35の観測 |
|---|---|
| ClipKitを標準IMEにして他アプリでコピー | 自動保存成功 |
| 履歴ボタンを実タップ | 独立エディタのEditTextに同文が入力された |
| 最小キーabc | 履歴文字列の後へabcを追加できた |
| IME非表示、サービス生存中 | コピー保存成功。追加試験ではdumpsysの `mInputShown=true → false` を確認 |
| 別IME（Gboard）が標準 | 自動保存されない。再選択後にその時点の最新clipだけ取得 |
| 機密フラグ付きclip | 履歴に保存されない |
| 同文を再コピー | 件数増加・取得時刻延長なし |
| 23件の異なるコピー | 最新20件を保持、古いものを除外 |
| 全削除→強制停止→再生成・再選択 | 空履歴を維持。同じclipの復活なし |
| `am force-stop` | OSがGboardへ標準IMEを変更。コピーの中間履歴は失われる。再選択で最新のみ回収 |
| `am crash` | 標準IMEはClipKitを維持。PID変化、永続履歴保持、OSによる再bind後のコピー取得を確認 |
| 3日超・未来時刻の保存データ | 端末読み取り時に除外（試験用時刻fixture。実時間3日の待機ではない） |
| 端末全体の再起動 | 両OSで標準IMEと履歴を維持、入力欄のフォーカス後にコピー取得成功。起動前・ロック中の取得は未確認 |

[API 33全統合ログ](evidence/device-api33.log)、[API 35全統合ログ](evidence/device-api35.log)。実出力抜粋:

```text
PASS: other-app copy saved with IME visible
PASS: history tap commitText reached independent editor
PASS: minimum key commitText
PASS: IME hidden copy saved while service alive
PASS: sensitive clip excluded
PASS: intermediate copy while stopped is unrecoverable
PASS: other default IME no automatic capture
PASS: device retention capped at newest 20
PASS: deletion survives recreation without current clip reimport
PASS: process PID changed after crash
ALL INTEGRATION CHECKS PASSED
```

実際のクラッシュ前後PID: API 33 `6677 → 6759`、API 35 `4416 → 4485`。強制停止時の別IMEフォールバックを見落とした初回試験の[観測ログ](evidence/force-stop-observation-api33.log)も保持し、再選択後の取得と区別した。

[API 33再起動・期限ログ](evidence/reboot-retention-api33.log)、[API 35再起動・期限ログ](evidence/reboot-retention-api35.log)。API 35の初回再起動試験は、boot_completed直後の検証Activity解決が一時的に未準備で失敗した（[初回実出力](evidence/reboot-early-activity-api35.log)）。再現スクリプトにActivity解決可能になるまでの上限つき待機を加えた。

再起動試験の最終実出力（両OSで成功）:

```text
PASS: device read prunes >3-day and future-dated records (seeded clock-boundary fixture)
PASS: IME shown true -> false via dumpsys; copy while hidden saved
Default IME after reboot: com.clipkit.prototype/.ClipKitIme
PASS: persisted history survives full emulator reboot
PASS: copy captured after reboot and editor focus
```

標準設定アプリでの追加一周はAPI 33で実施。検索欄へ `clipkit-stock-roundtrip` を入力→長押しの標準Copy→検索欄のClear text→IME履歴ボタンのタップ→同文入力を確認。[実出力](evidence/stock-settings-api33.log)、[UI階層](evidence/stock-settings-api33.xml)、[結果画面](evidence/stock-settings-api33.png)。入力先パッケージは `com.google.android.settings.intelligence`、クラスは `android.widget.EditText`。

## 再現コマンド

SDKをANDROID_HOMEまたは未追跡の `android/local.properties` の `sdk.dir` で指定し、Java 17を使用する。

```sh
emulator -avd Pixel_6_API_33 -no-window -no-audio -no-snapshot-save
# 別ターミナル。対象はエミュレータ限定。ClipKit履歴を初期化する。
./android/scripts/verify-emulator.sh emulator-5554
python3 android/scripts/verify-reboot-retention.py emulator-5554
```

API 35は `Pixel_7_API_35_Play -port 5556` と `emulator-5556` に置換。各スクリプトは `ro.kernel.qemu=1` を必須とし、開始時の標準IMEを終了時に復元する。UiAutomation出力はstatusと最終結果に同じ行が含まれる。テストスクリプトは `ALL INTEGRATION CHECKS PASSED` とFAIL不在を判定し、単なるadbの終了コードだけで成功扱いしない。

標準設定アプリの再現はPixel 6 / API 33の1080×2400画面で、設定のSearch settingsを開き、試験用文字列を入力して長押ししCopyを選択。Clear textで空欄にしてClipKitの同文履歴を押す。`adb shell am start -a android.settings.SETTINGS` で設定を開ける。UI階層の取得には `adb shell uiautomator dump /sdcard/clipkit-stock-result.xml` を使用した。ブラウザは使わない。

## 実機未確認・残る制約

接続実機がなく、メーカー固有の電池最適化・サービス停止、端末ロック中・ユーザー解除前、API 29/30/31/32/34/36での実行、実機Gboardとの常用切替、全アプリとの互換性は未確認。複数の中間コピーをプロセス不在中に復元することはできない。3日経過の実時間待機は行っていない。IME非表示での成功はサービス生存中の結果であり、OSがサービスを破棄した状態の常時収集保証にはならない。

実機で続ける場合は、テスト専用端末でAPKを導入し、本人がClipKitを有効化・選択する。メモアプリでテスト文字列をコピー→別入力欄を開く→履歴タップ→非表示コピー→機密flag対応アプリでコピー→別IMEへの切替→全削除→再起動の順で確認する。機密clip試験は独立fixtureでも再現可能。個人端末の標準IMEは自動変更しない。一般キー配列・日本語変換・検索・ピン・画像・同期・課金・広告・公開は未実装。

## 公式資料

- [Android 10のクリップボード制限](https://developer.android.com/about/versions/10/privacy/changes): デフォルトIMEまたはフォーカスのあるアプリだけが取得可能。
- [InputMethodServiceの作成と入力](https://developer.android.com/develop/ui/views/touch-and-input/creating-input-method): システム登録とInputConnectionへの文字列送信。
- [Androidのコピー・貼付け](https://developer.android.com/develop/ui/views/touch-and-input/copy-paste): ClipboardManager、Android 13のコピー確認表示、機密フラグ。
- [機密clipboardの扱い](https://developer.android.com/privacy-and-security/risks/secure-clipboard-handling): EXTRA_IS_SENSITIVE / android.content.extra.IS_SENSITIVE。

資料上の取得可能条件と、実際のサービス生存期間・OS再bindは別の問題として測定した。初回コピーテストではAndroid 13+の確認オーバーレイが最小キーと重なり、表示終了を待つようテストを修正した。root、製品でのADB常用、Accessibilityによるclipboard制限回避は採用していない。
