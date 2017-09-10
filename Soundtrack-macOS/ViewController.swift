//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Cocoa

class ViewController: NSViewController, PlaybackControllerDelegate {

    var playbackController: PlaybackController!

    var useRadio: Bool = false

    // MARK: UI

    @IBOutlet weak var playButton: NSButton!

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
                return AudioSessionMacOS(queue: queue)
            }

            let makePlayer = { queue in
                //return AudioFilePlayer.makeDemo()
                return AACShoutcastStreamPlayer(url: url, queue: queue)
            }

            playbackController = PlaybackController(delegate: self, makeSession: makeSession, makePlayer: makePlayer)
        }
    }

    @IBAction func changeSource(_ sender: NSSegmentedControl) {
        useRadio = sender.selectedSegment == 1
        log.info("User changed source; use radio = \(useRadio)")

        playbackController.pauseIfPlaying()
    }

    @IBAction func togglePlayPause(_ sender: NSButton) {
        log.info("User toggled playback state")
        playbackController.togglePlayPause()
    }

    // MARK: UI Playback State

    private func indicatePlaybackUnavailability() {
        playButton.title = NSLocalizedString("Loading", comment: "")
        playButton.isEnabled = false
    }

    private func indicatePlaybackAvailability() {
        indicatePlaybackReadiness()
        playButton.isEnabled = true
    }

    private func indicatePlaybackReadiness() {
        playButton.title = NSLocalizedString("Play", comment: "")
    }

    private func indicatePlayback() {
        playButton.title = NSLocalizedString("Pause", comment: "")
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
