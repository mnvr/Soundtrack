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

        testConfiguration()

        indicatePlaybackUnavailability()

        let session = AudioSessionMacOS.shared
        playbackController = PlaybackController(session: session, delegate: self) {
            return LocalAudioFilePlayer.makeExample()
        }
    }

    // WIP --

    var shoutcastPlayer: SHOUTcastPlayer?

    private func testConfiguration() {
        observe(.ConfigurationDidChange, with: #selector(maybeTestConnection))
        maybeTestConnection()
    }

    @objc private func maybeTestConnection() {
        if let url = Configuration.shared.shoutcastURL, shoutcastPlayer == nil {
            shoutcastPlayer = SHOUTcastPlayer(url: url)
            shoutcastPlayer?.connect()
        }
    }

    // WIP END --

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
