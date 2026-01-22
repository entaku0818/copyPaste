import SwiftUI
import AVKit
import AVFoundation
import OSLog

struct VideoPlayerView: UIViewControllerRepresentable {
    let onPiPStateChange: (Bool) -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.delegate = context.coordinator

        // AVAudioSessionの設定
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try audioSession.setActive(true)
            context.coordinator.logger.info("AVAudioSession configured")
        } catch {
            context.coordinator.logger.error("Failed to configure AVAudioSession: \(error.localizedDescription)")
        }

        // ビデオファイルを読み込み
        guard let videoPath = Bundle.main.path(forResource: "transparent_with_audio", ofType: "mp4") else {
            context.coordinator.logger.error("Video file not found")
            return controller
        }

        let url = URL(fileURLWithPath: videoPath)
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        player.actionAtItemEnd = .none

        // ループ再生
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.showsPlaybackControls = true

        // ビデオレイヤーを小さく透明に
        controller.videoGravity = .resizeAspect
        if let playerLayer = controller.view.layer.sublayers?.first {
            playerLayer.opacity = 0.3
        }

        context.coordinator.logger.info("AVPlayerViewController setup complete")

        // 自動再生とPiP起動
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            player.play()
            context.coordinator.logger.info("Video playback started")

            // さらに少し待ってから自動でPiPを起動
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                context.coordinator.logger.info("Auto-starting PiP...")
                controller.startPictureInPicture()
            }
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // 更新なし
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPiPStateChange: onPiPStateChange)
    }

    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let logger = Logger(subsystem: "com.copyPaste", category: "VideoPlayer")
        let onPiPStateChange: (Bool) -> Void

        init(onPiPStateChange: @escaping (Bool) -> Void) {
            self.onPiPStateChange = onPiPStateChange
        }

        func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator) {
            logger.info("Will begin full screen")
        }

        func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator) {
            logger.info("Will end full screen")
        }

        func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            logger.info("✅ PiP will start")
            onPiPStateChange(true)
        }

        func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            logger.info("✅ PiP did start - clipboard monitoring should continue")
        }

        func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            logger.info("⚠️ PiP will stop")
            onPiPStateChange(false)
        }

        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            logger.info("⚠️ PiP did stop")
        }

        func playerViewController(_ playerViewController: AVPlayerViewController, failedToStartPictureInPictureWithError error: any Error) {
            logger.error("❌ PiP failed to start: \(error.localizedDescription)")
            onPiPStateChange(false)
        }
    }
}
