import SwiftUI

/// レビュー依頼の事前確認。
///
/// 以前は `.presentationDetents([.medium])` のボトムシートだったが、
/// ドラッグで払い落とせてタブバーにも被るため、画面中央のモーダルに変更した。
/// 「満足しているか」を尋ねる分岐はこの回答で決まるので、
/// 意図せず閉じられるより、明示的にどちらかを選んでもらう形にする。
struct SatisfactionPromptView: View {
    let onSatisfied: () -> Void
    let onUnsatisfied: () -> Void

    var body: some View {
        ZStack {
            // 背面を暗くして前面のカードに集中させる
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    Image(systemName: "clipboard.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("satisfaction.title")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("satisfaction.question")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button {
                        onSatisfied()
                    } label: {
                        Label("satisfaction.satisfied", systemImage: "star.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(ClipKitRadius.control)
                    }

                    Button {
                        onUnsatisfied()
                    } label: {
                        Label("satisfaction.improve", systemImage: "bubble.left.and.bubble.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.15))
                            .foregroundColor(.primary)
                            .cornerRadius(ClipKitRadius.control)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .background(ClipKitColor.card)
            .cornerRadius(ClipKitRadius.card)
            .padding(.horizontal, 32)
        }
    }
}
