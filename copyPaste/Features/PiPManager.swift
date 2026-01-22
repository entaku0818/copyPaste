import Foundation
import AVKit
import AVFoundation
import UIKit
import OSLog

class PiPManager: NSObject {
    static let shared = PiPManager()
    private var pipController: AVPictureInPictureController?
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private let logger = Logger(subsystem: "com.copyPaste", category: "PiP")
    private var shouldStartPiP = false
    private var playerObserver: NSKeyValueObservation?
    private var attachedWindow: UIWindow?
    private var isSetup = false

    override init() {
        super.init()
    }
    
    private func setupPiP() {
        logger.info("Setting up PiP...")

        // AVAudioSessionの設定（PiPに必須）
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try audioSession.setActive(true)
            logger.info("AVAudioSession configured successfully")
        } catch {
            logger.error("Failed to configure AVAudioSession: \(error.localizedDescription)")
        }

        // 1秒の透明な動画を作成（音声トラック付き）
        let videoPath = Bundle.main.path(forResource: "transparent_with_audio", ofType: "mp4")
        guard let videoPath else {
            logger.error("Failed to find video file")
            return
        }
        logger.info("Found video file at: \(videoPath)")

        let url = URL(fileURLWithPath: videoPath)
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.actionAtItemEnd = .none
        logger.info("Created AVPlayer")

        // ループ再生の設定
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.logger.debug("Video ended, looping...")
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        playerLayer?.opacity = 0
        logger.info("Created AVPlayerLayer")

        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            logger.error("PiP is not supported on this device")
            return
        }
        logger.info("PiP is supported")

        pipController = AVPictureInPictureController(playerLayer: playerLayer!)
        pipController?.delegate = self

        // プレイヤーの再生状態を監視
        playerObserver = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, change in
            guard let self = self else { return }
            if player.timeControlStatus == .playing {
                self.logger.info("Player started playing")
                if self.shouldStartPiP && self.pipController?.isPictureInPictureActive == false {
                    self.logger.info("Player is playing, attempting PiP")
                    // メインスレッドで少し遅延させて実行
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.attemptStartPiP()
                    }
                }
            }
        }

        logger.info("Setup complete")
    }
    
    func startPiP() {
        logger.info("Starting PiP...")

        // 初回のみセットアップ
        if !isSetup {
            logger.info("First time setup...")
            setupPiP()
            isSetup = true
        }

        shouldStartPiP = true

        guard let playerLayer else {
            logger.error("PlayerLayer is nil")
            return
        }
        logger.debug("PlayerLayer exists")

        guard let pipController else {
            logger.error("PipController is nil")
            return
        }
        logger.debug("PipController exists")

        // ForegroundActiveなシーンを探す
        guard let activeScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {

            logger.warning("No foreground active scene yet. Waiting for scene activation...")

            // シーンがactiveになるまで待つ
            NotificationCenter.default.addObserver(
                forName: UIScene.didActivateNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let scene = notification.object as? UIWindowScene,
                      scene.activationState == .foregroundActive else { return }

                self?.logger.info("Scene became active during startup, retrying startPiP")
                NotificationCenter.default.removeObserver(self as Any, name: UIScene.didActivateNotification, object: nil)

                // 再試行
                self?.startPiP()
            }
            return
        }

        logger.info("Found foreground active scene")

        guard let window = activeScene.windows.first(where: { $0.isKeyWindow }) ?? activeScene.windows.first else {
            logger.error("Failed to get window from active scene")
            return
        }

        logger.info("Got window from foreground active scene, adding playerLayer")
        window.layer.addSublayer(playerLayer)
        attachedWindow = window
        logger.debug("Added playerLayer to window: \(window), scene state: \(activeScene.activationState.rawValue)")

        // プレイヤーを再生開始（KVOで再生開始を検知してPiPを起動）
        player?.play()
        logger.info("Started player - waiting for playback to begin")
    }

    private func attemptStartPiP() {
        guard let pipController else {
            logger.error("PipController is nil in attemptStartPiP")
            return
        }

        guard shouldStartPiP else {
            logger.debug("shouldStartPiP is false, skipping")
            return
        }

        guard pipController.isPictureInPictureActive == false else {
            logger.debug("PiP already active, skipping")
            return
        }

        // playerLayerが追加されたwindowのシーンの状態を確認
        guard let attachedWindow = attachedWindow,
              let windowScene = attachedWindow.windowScene else {
            logger.error("Attached window or its scene is nil")
            return
        }

        let sceneState = windowScene.activationState
        logger.info("Attached window scene state: \(sceneState.rawValue)")

        guard sceneState == .foregroundActive else {
            logger.error("Window scene is not foreground active (state: \(sceneState.rawValue)). Waiting...")

            // このシーンがForegroundActiveになるまで待機
            NotificationCenter.default.addObserver(
                forName: UIScene.didActivateNotification,
                object: windowScene,
                queue: .main
            ) { [weak self] notification in
                guard let scene = notification.object as? UIWindowScene,
                      scene.activationState == .foregroundActive else { return }

                self?.logger.info("Window scene became active, retrying PiP")
                NotificationCenter.default.removeObserver(self as Any, name: UIScene.didActivateNotification, object: windowScene)

                // 再試行
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.attemptStartPiP()
                }
            }
            return
        }

        logger.info("Window scene is foreground active, starting PiP now...")
        pipController.startPictureInPicture()
        logger.info("Called startPictureInPicture()")
    }
    
    func stopPiP() {
        logger.info("Stopping PiP...")
        shouldStartPiP = false
        playerObserver?.invalidate()
        playerObserver = nil
        player?.pause()
        pipController?.stopPictureInPicture()
        playerLayer?.removeFromSuperlayer()
        attachedWindow = nil
        logger.info("Stopped")
    }

    deinit {
        playerObserver?.invalidate()
    }
}

extension PiPManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        logger.info("PiP will start")
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        logger.info("PiP did start successfully!")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        logger.error("PiP failed to start: \(error.localizedDescription)")
        logger.error("Error details: \(error)")
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        logger.info("PiP will stop")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        logger.info("PiP did stop")
    }
} 