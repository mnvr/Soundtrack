//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit
import AVFoundation

// FIXME: This is mostly a verbatim copy of the macOS view controller.

class ViewController: UIViewController, PlaybackControllerDelegate {

    var playbackController: PlaybackController!

    // MARK: UI

    @IBOutlet weak var playButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        indicatePlaybackUnavailability()

        maybeMakePlaybackController()
        observeConfigurationChange()
    }

    private func observeConfigurationChange() {
        observe(.ConfigurationDidChange, with: #selector(maybeMakePlaybackController))
    }

    @objc private func maybeMakePlaybackController() {
        if let url = Configuration.shared.shoutcastURL, playbackController == nil {
            playbackController = makePlaybackController(url: url)
        }
    }

    private func makePlaybackController(url: URL) -> PlaybackController {
        let makeSession = { queue in
            return AudioSessionIOS(queue: queue)
        }

        let makePlayer = { queue in
            return AACShoutcastStreamPlayer(url: url, queue: queue)
        }

        return PlaybackController(delegate: self, makeSession: makeSession, makePlayer: makePlayer)
    }

    @IBAction func togglePlayPause(_ sender: UIButton) {
        log.info("User toggled playback state")
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
