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

    var useRadio: Bool = false

    // MARK: UI

    @IBOutlet weak var playButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        indicatePlaybackUnavailability()

        makePlaybackController()
        observeConfigurationChange()
    }

    private func observeConfigurationChange() {
        observe(.ConfigurationDidChange, with: #selector(makePlaybackController))
    }

    @objc private func makePlaybackController() {
        if let url = Configuration.shared.shoutcastURL, playbackController == nil {
            let makeSession = { queue in
                return AudioSessionIOS(queue: queue)
            }

            let makePlayer = { queue in
                //return AudioFilePlayer.makeDemo()
                return AACShoutcastStreamPlayer(url: url, queue: queue)
            }

            playbackController = PlaybackController(delegate: self, makeSession: makeSession, makePlayer: makePlayer)
        }
    }

    @IBAction func changeSource(_ sender: UISegmentedControl) {
        useRadio = sender.selectedSegmentIndex == 1
        log.info("User changed source; use radio = \(useRadio)")

        playbackController.pauseIfPlaying()
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
