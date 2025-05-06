import Foundation
import AVKit
import UIKit

class PiPManager: NSObject {
    static let shared = PiPManager()
    private var pipController: AVPictureInPictureController?
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    
    override init() {
        super.init()
        setupPiP()
    }
    
    private func setupPiP() {
        // 1秒の透明な動画を作成
        let videoPath = Bundle.main.path(forResource: "transparent", ofType: "mp4")
        guard let videoPath else {
            print("Failed to find video file")
            return
        }
        
        let url = URL(fileURLWithPath: videoPath)
        player = AVPlayer(url: url)
        player?.actionAtItemEnd = .none
        
        // ループ再生の設定
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        playerLayer?.opacity = 0
        
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("PiP is not supported")
            return
        }
        
        pipController = AVPictureInPictureController(playerLayer: playerLayer!)
        pipController?.delegate = self
    }
    
    func startPiP() {
        guard let playerLayer else { return }
        
        // PiPを開始する前に、レイヤーをビューに追加する必要がある
        if let window = UIApplication.shared.windows.first {
            window.layer.addSublayer(playerLayer)
            player?.play()
            
            // PiPを開始
            pipController?.startPictureInPicture()
        }
    }
    
    func stopPiP() {
        player?.pause()
        pipController?.stopPictureInPicture()
        playerLayer?.removeFromSuperlayer()
    }
}

extension PiPManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiP will start")
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiP did start")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("PiP failed to start: \(error)")
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiP will stop")
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiP did stop")
    }
} 