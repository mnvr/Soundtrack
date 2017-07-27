//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Cocoa

class ViewController: NSViewController, AudioPlayerDelegate {

    let session = AudioSessionMacOS.shared
    var player: AudioPlayer!

    var useRadio: Bool = false

    // MARK: UI

    @IBOutlet weak var playButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        indicatePlaybackUnavailability()

        player = AudioPlayer.makeExampleFilePlayer(session: session, delegate: self)
    }

    @IBAction func changeSource(_ sender: NSSegmentedControl) {
        useRadio = sender.selectedSegment == 1
        logInfo("User changed source; use radio = \(useRadio)")

        player.pauseIfPlaying()
    }

    @IBAction func togglePlayPause(_ sender: NSButton) {
        logInfo("User toggled playback state")
        player.togglePlayPause()
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

    // MARK: AudioPlayer Delegate

    func audioPlayerDidBecomeAvailable(_ audioPlayer: AudioPlayer) {
        DispatchQueue.main.async { [weak self] in
            self?.indicatePlaybackAvailability()
        }
    }

    func audioPlayerDidBecomeUnavailable(_ audioPlayer: AudioPlayer) {
        DispatchQueue.main.async { [weak self] in
            self?.indicatePlaybackUnavailability()
        }
    }

    func audioPlayerDidPlay(_ audioPlayer: AudioPlayer) {
        DispatchQueue.main.async { [weak self] in
            self?.indicatePlayback()
        }
    }

    func audioPlayerDidPause(_ audioPlayer: AudioPlayer) {
        DispatchQueue.main.async { [weak self] in
            self?.indicatePlaybackReadiness()
        }
    }

}
