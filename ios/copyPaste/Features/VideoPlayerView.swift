import SwiftUI
import UIKit

/// PiP のソースビューを提供する UIViewRepresentable
/// AVPictureInPictureController に activeVideoCallSourceView として渡すためのアンカー View
struct PiPSourceView: UIViewRepresentable {
    let onSetup: (UIView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            onSetup(view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
