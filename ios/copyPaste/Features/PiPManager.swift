import Foundation
import AVKit
import AVFoundation
import UIKit
import OSLog
import Combine

@MainActor
class PiPManager: NSObject, ObservableObject {
    static let shared = PiPManager()
    private var pipController: AVPictureInPictureController?
    private let pipContentVC = ClipboardPiPViewController()
    private let logger = Logger(subsystem: "com.clipkit", category: "PiP")
    @Published var showStartError = false
    private var isStarting = false
    private var startTask: Task<Void, Never>?
    var onPiPStateChange: ((Bool) -> Void)?

    override init() {
        super.init()
    }

    // MARK: - Setup

    func setup(sourceView: UIView) {
        guard pipController == nil else { return }
        setupAudioSession()
        setCompactMode(UserDefaults.standard.bool(forKey: "pipCompactMode"))

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
        guard startTask == nil, !isStarting, pipController?.isPictureInPictureActive != true else { return }
        showStartError = false
        startTask = Task { @MainActor [weak self] in
            defer { self?.startTask = nil }
            // Cold launches need a window, an active scene and a ready PiP controller.
            for _ in 0..<50 {
                guard !Task.isCancelled, let self else { return }
                if UIApplication.shared.applicationState == .active,
                   let controller = self.pipController, controller.isPictureInPicturePossible {
                    self.isStarting = true
                    controller.startPictureInPicture()
                    return
                }
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
            self?.showStartError = true
        }
    }

    func stopPiP() {
        startTask?.cancel()
        pipController?.stopPictureInPicture()
        logger.info("PiP stop requested")
    }

    func setCompactMode(_ compact: Bool) {
        pipContentVC.setCompactMode(compact)
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
        isStarting = false
        onPiPStateChange?(true)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        logger.info("PiP did stop")
        isStarting = false
        onPiPStateChange?(false)
    }

    func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        logger.error("PiP failed to start: \(error.localizedDescription)")
        showStartError = true
        isStarting = false
        onPiPStateChange?(false)
    }

    func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        logger.info("PiP will start")
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ controller: AVPictureInPictureController) {
        logger.info("PiP will stop")
    }
}
