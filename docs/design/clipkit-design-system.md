# ClipKit Design System — "Indigo"（2026-07 リニューアル）

元デザイン: `clipkit-redesign-reference.html`（案A: Teal / 案B: Indigo の比較 → **Indigo採用**）。
実装: `ios/copyPaste/DesignSystem/ClipKitDesign.swift`, `ClipKitComponents.swift`, `ItemCategory+ClipKitColors.swift`。

## カラートークン

| トークン | 値 | 用途 |
|---|---|---|
| `ClipKitColor.indigo` | `#5B5BD6` | ブランドメインカラー（AccentColorにも設定） |
| `ClipKitColor.indigoLight` | `#7B78F0` | グラデーション用の明るいインディゴ、ダークモードのAccentColor |
| `ClipKitColor.brandGradient` | `indigoLight → indigo`（135deg） | CTAボタン・アイコンのグラデーション背景 |
| `ClipKitColor.canvas` | `systemGroupedBackground` | 画面キャンバス（カードを浮かせる背景） |
| `ClipKitColor.card` | `secondarySystemGroupedBackground` | カード・行の背景 |
| `ClipKitColor.darkSurface` | `#14142B` | ダークヒーローカード・Paywall背景 |
| `ClipKitColor.favorite` | `#F5B800` | お気に入り星 |
| `ClipKitColor.crown` | `#FFE08A` | Proクラウンアイコン |
| `ClipKitColor.destructive` | `#E5484D` | 削除・危険アクション |
| `ClipKitColor.success` | `#22A04C` | 完了・成功表示 |

### カテゴリバッジ配色（背景・前景ペア）

| バッジ | 背景 | 前景 | 用途 |
|---|---|---|---|
| `badgeIndigo` | `#ECEBFB` | `#5B5BD6` | テキスト |
| `badgeBlue` | `#E2EBFF` | `#2F6BFF` | URL |
| `badgePurple` | `#E9E3FB` | `#7B5BD6` | メール |
| `badgeAmber` | `#F3E9D6` | `#C98A00` | 住所・画像 |
| `badgeGreen` | `#DFF3E6` | `#22A04C` | 電話 |
| `badgeCode` | `#1C1C2E`（反転） | `#A8F0D0` | コード |
| `badgeGray` | `tertiarySystemFill` | `secondaryLabel` | ファイル・未分類 |

## 角丸・余白

- カードグループ: 16pt（`ClipKitRadius.card`）
- アイコンバッジ: 12pt（`ClipKitRadius.badge`）
- CTAボタン: 14pt（`ClipKitRadius.control`）
- セグメントコントロール: 9pt（`ClipKitRadius.segment`）
- 画面横余白: 16pt（`ClipKitSpacing.screenPadding`）
- カード内余白: 14pt（`ClipKitSpacing.cardPadding`）

## タイポグラフィ

- 画面タイトル: 30pt Bold（`ClipKitFont.screenTitle`）
- カードタイトル: 17pt Bold
- 行タイトル: 14.5pt Regular / Semibold
- メタ情報: 12pt
- セクションキャプション: 11pt Bold + tracking

## コンポーネント

- `IconBadge` — 角丸12ptの正方形にカテゴリ色＋SF Symbol
- `CardGroup` — Listを使わない画面向けの白カードコンテナ（角丸16pt）
- `.clipKitCardRow(_:)` — `List`の行をカードグループ風に見せるモディファイア。`swipeActions`等のList機能を保ったまま、先頭/末尾行だけ角丸をつけ、中間行の下端に区切り線を引く
- `DarkHeroCard` — ダークサーフェスのヒーローカード（Pro訴求・常時起動ステータス）
- `PrimaryGradientButtonStyle` — ブランドグラデーションのCTAボタン
- `PillSegmentedControl` — 角丸ピル型セグメント（現状は履歴のカテゴリチップで使用継続、将来のセグメント化用に用意）

## 適用画面

| 画面 | 変更内容 |
|---|---|
| 履歴 (`ClipboardHistoryView`) | List行をカードグループ化、カテゴリチップをIndigo配色 |
| お気に入り (`FavoritesView`) | カードグループ化、Pro誘導バナーをブランドグラデーション化 |
| 常時起動 (`MonitoringView`) | ダークヒーローカード＋カードグループのコントロール |
| 設定 (`SettingsView`) | Proダークヒーローカード＋アイコンバッジ付きカードグループ |
| Paywall (`PaywallView`) | ダークテーマ全面適用（`.preferredColorScheme(.dark)`）、特典行をアイコンバッジ化 |
| オンボーディング (`OnboardingView`) | ブランドグラデーションアイコン＋グラデーションCTA |
| ゴミ箱 (`TrashView`) | カードグループ化、復元アイコンをIndigo化 |
| 定型文 (`SnippetsView`) | カードグループ化、アイコンバッジ追加 |
| キーボード拡張 (`KeyboardViewController`) | `KeyboardDesign.swift`のUIColorトークンで配色統一（UIKit側は別トークン定義、値は同一） |

## 既知の制約・今後の課題

- Paywallのみ強制ダークモード。他画面はシステム配色に追従（ライト/ダーク自動）
- キーボード拡張はUIKitのため`ClipKitColor`(SwiftUI)を直接参照できず、`KeyboardDesign.swift`に同値のUIColorトークンを複製している。値を変更する際は両方更新すること
- ウィジェット拡張（`ClipboardWidget`）は今回のスコープ外
