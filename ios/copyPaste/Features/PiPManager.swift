import Foundation
import AVKit
import AVFoundation
import UIKit
import OSLog

@MainActor
class PiPManager: NSObject {
    static let shared = PiPManager()
    private var pipController: AVPictureInPictureController?
    private let pipContentVC = ClipboardPiPViewController()
    private let logger = Logger(subsystem: "com.clipkit", category: "PiP")
    var onPiPStateChange: ((Bool) -> Void)?

    override init() {
        super.init()
    }

    // MARK: - Setup

    func setup(sourceView: UIView) {
        setupAudioSession()

        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            logger.error("PiP not supported on this device")
            return
        }

        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: pipContentVC
        )
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        logger.info("PiP setup complete with custom content source")
    }

    // MARK: - Control

    func startPiP() {
        guard let pipController else {
            logger.error("PiP not set up yet")
            return
        }
        pipController.startPictureInPicture()
        logger.info("PiP start requested")
    }

    func stopPiP() {
        pipController?.stopPictureInPicture()
        logger.info("PiP stop requested")
    }

    // MARK: - Content

    func updateItems(_ items: [ClipboardItem]) {
        pipContentVC.updateItems(items)
    }

    // MARK: - Private

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            logger.info("AVAudioSession configured for background")
        } catch {
            logger.error("AVAudioSession setup failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PiPManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        logger.info("PiP did start")
        onPiPStateChange?(true)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        logger.info("PiP did stop")
        onPiPStateChange?(false)
    }

    func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        logger.error("PiP failed to start: \(error.localizedDescription)")
        onPiPStateChange?(false)
    }

    func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        logger.info("PiP will start")
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ controller: AVPictureInPictureController) {
        logger.info("PiP will stop")
    }
}
