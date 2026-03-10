import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    var onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "doc.on.clipboard.fill",
            imageColor: .blue,
            title: "ClipKitへようこそ",
            description: "コピーしたテキスト・URL・画像を自動で記録。\nいつでも履歴から取り出せます。"
        ),
        OnboardingPage(
            systemImage: "play.circle.fill",
            imageColor: .green,
            title: "常時起動で自動記録",
            description: "「常時起動」タブでモニタリングを開始すると、コピーした内容を自動で保存します。"
        ),
        OnboardingPage(
            systemImage: "clipboard",
            imageColor: .orange,
            title: "ペースト許可の設定",
            description: "毎回ダイアログが出ないよう、\niOSの設定から許可しておくと便利です。",
            hasSettingsButton: true
        ),
        OnboardingPage(
            systemImage: "checkmark.circle.fill",
            imageColor: .purple,
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
                        .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.bottom, 24)

            // ボタン
            if currentPage < pages.count - 1 {
                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    Text("次へ")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            } else {
                Button {
                    onComplete()
                } label: {
                    Text("はじめる")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.systemImage)
                .font(.system(size: 80))
                .foregroundColor(page.imageColor)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            if page.hasSettingsButton {
                VStack(alignment: .leading, spacing: 8) {
                    Text("設定 → プライバシーとセキュリティ → ペースト → ClipKit")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("「他のAppからペースト」を **許可** に変更")
                        .font(.subheadline)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("設定を開く", systemImage: "arrow.up.right.square")
                            .font(.subheadline)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

private struct OnboardingPage {
    let systemImage: String
    let imageColor: Color
    let title: String
    let description: String
    var hasSettingsButton: Bool = false
}
