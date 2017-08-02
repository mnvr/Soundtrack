//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit
import AVFoundation

class ViewController: UIViewController, PlaybackControllerDelegate {

    let session = AudioSessionIOS.shared
    var playbackController: PlaybackController!

    var useRadio: Bool = false

    // MARK: UI

    @IBOutlet weak var playButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        indicatePlaybackUnavailability()

        let session = AudioSessionIOS.shared
        playbackController = PlaybackController(session: session, delegate: self) {
            return LocalAudioFilePlayer.makeExample()
        }
    }

    @IBAction func changeSource(_ sender: UISegmentedControl) {
        useRadio = sender.selectedSegmentIndex == 1
        logInfo("User changed source; use radio = \(useRadio)")

        playbackController.pauseIfPlaying()
    }

    @IBAction func togglePlayPause(_ sender: UIButton) {
        logInfo("User toggled playback state")
        playbackController.togglePlayPause()
    }

    // MARK: UI Playback State

    private func indicatePlaybackUnavailability() {
        playButton.setTitle(NSLocalizedString("Loading", comment: ""), for: .normal)
        playButton.isEnabled = false
    }

    private func indicatePlaybackAvailability() {
        indicatePlaybackReadiness()
        playButton.isEnabled = true
    }

    private func indicatePlaybackReadiness() {
        playButton.setTitle(NSLocalizedString("Play", comment: ""), for: .normal)
    }

    private func indicatePlayback() {
        playButton.setTitle(NSLocalizedString("Pause", comment: ""), for: .normal)
    }

    // MARK: Playback Controller Delegate
    
    func playbackControllerDidBecomeAvailable(_ playbackController: PlaybackController) {
        DispatchQueue.main.async { [weak self] in
            self?.indicatePlaybackAvailability()
        }
    }

    func playbackControllerDidBecomeUnavailable(_ playbackController: PlaybackController) {
        DispatchQueue.main.async { [weak self] in
            self?.indicatePlaybackUnavailability()
        }
    }

    func playbackControllerDidPlay(_ playbackController: PlaybackController) {
        DispatchQueue.main.async { [weak self] in
            self?.indicatePlayback()
        }
    }

    func playbackControllerDidPause(_ playbackController: PlaybackController) {
        DispatchQueue.main.async { [weak self] in
            self?.indicatePlaybackReadiness()
        }
    }

}
