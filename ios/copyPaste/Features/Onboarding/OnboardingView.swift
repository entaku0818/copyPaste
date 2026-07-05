import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    var onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "doc.on.clipboard.fill",
            title: "ClipKitへようこそ",
            description: "コピーしたテキスト・URL・画像を自動で記録。\nいつでも履歴から取り出せます。"
        ),
        OnboardingPage(
            systemImage: "play.circle.fill",
            title: "常時起動で自動記録",
            description: "「常時起動」タブでモニタリングを開始すると、コピーした内容を自動で保存します。"
        ),
        OnboardingPage(
            systemImage: "clipboard",
            title: "ペースト許可の設定",
            description: "毎回ダイアログが出ないよう、\niOSの設定から許可しておくと便利です。",
            hasSettingsButton: true
        ),
        OnboardingPage(
            systemImage: "checkmark.circle.fill",
            title: "準備完了！",
            description: "さっそく使ってみましょう。"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // ページインジケーター
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? ClipKitColor.indigo : ClipKitColor.textTertiary.opacity(0.4))
                        .frame(width: 9, height: 9)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.bottom, 24)

            // ボタン
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    onComplete()
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "次へ" : "はじめる")
            }
            .buttonStyle(PrimaryGradientButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(ClipKitColor.canvas)
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(ClipKitColor.brandGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: ClipKitColor.indigoLight.opacity(0.4), radius: 24, y: 12)
                Image(systemName: page.systemImage)
                    .font(.system(size: 52))
                    .foregroundColor(.white)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 27, weight: .heavy))
                    .foregroundColor(ClipKitColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.system(size: 15))
                    .foregroundColor(ClipKitColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            if page.hasSettingsButton {
                VStack(alignment: .leading, spacing: 8) {
                    Text("設定 → プライバシーとセキュリティ → ペースト → ClipKit")
                        .font(.subheadline)
                        .foregroundColor(ClipKitColor.textSecondary)
                    Text("「他のAppからペースト」を **許可** に変更")
                        .font(.subheadline)
                        .foregroundColor(ClipKitColor.textPrimary)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("設定を開く", systemImage: "arrow.up.right.square")
                            .font(.subheadline)
                            .foregroundColor(ClipKitColor.indigo)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(ClipKitColor.card)
                .clipShape(RoundedRectangle(cornerRadius: ClipKitRadius.card, style: .continuous))
                .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

private struct OnboardingPage {
    let systemImage: String
    let title: String
    let description: String
    var hasSettingsButton: Bool = false
}
