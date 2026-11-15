# ClipKit Android IME prototype

Android 10+ (minSdk 29), compile/target SDK 36, Java 17, AGP 8.13.2, Gradle 8.13.
独立した試作。iOS/Functionsに依存しません。課金・同期・広告・画像は対象外です。

```sh
cd android
# ANDROID_HOME、または未追跡のlocal.propertiesにsdk.dirを設定
./gradlew :app:assembleDebug :app:lint :app:testDebugUnitTest
# エミュレータだけ。2つの試作アプリをインストールし、ClipKit履歴を初期化します。
./scripts/verify-emulator.sh emulator-5554
# 追加の期限境界fixtureと端末再起動（エミュレータだけ）
python3 scripts/verify-reboot-retention.py emulator-5554
```

APK: `app/build/outputs/apk/debug/app-debug.apk`。
`fixture` は独立したコピー元・入力先アプリ、`fixture/src/androidTest` はOSのUIテスト機構による検証専用コードです。製品アプリにはAccessibility権限やテスト用の取得APIを含めません。

アプリの設定案内からキーボードを有効化し、IME選択でClipKitを選択してください。
IMEの履歴ボタンは現在の入力欄へ `commitText` します。システムクリップボードへ再コピーしません。
最小キーはabc、空白、削除、改行。通常入力は「IME切替」から別キーボードへ戻します。

保存はアプリ専用領域。機密フラグ付きclip、URI/Intent、複数item、空文字、100,000文字超は除外します。
重複は完全一致で抑止し、元の取得時刻を維持。全削除後は同じclipを再起動だけで取り直しません。
期限は履歴読み取り・保存・貼付け時に評価し、常時タイマーによる物理消去は行いません。
別IME中やプロセス不在中の連続コピーは保存できず、再選択時に取得できるのはその時点のclipだけです。
バックアップ・端末移行を除外、ネットワーク権限なし。収集テキストのアプリログ出力はありません。

検証結果・制約・実機の確認手順: [result.md](../docs/android-prototype/result.md)
