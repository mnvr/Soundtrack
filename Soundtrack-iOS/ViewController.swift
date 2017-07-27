//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AudioPlayerDelegate {

    let session = AudioSessionIOS.shared
    var player: AudioPlayer!

    var useRadio: Bool = false

    // MARK: UI

    @IBOutlet weak var playButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        indicatePlaybackUnavailability()

        player = AudioPlayer.makeExampleFilePlayer(session: session, delegate: self)
    }

    @IBAction func changeSource(_ sender: UISegmentedControl) {
        useRadio = sender.selectedSegmentIndex == 1
        logInfo("User changed source; use radio = \(useRadio)")

        player.pauseIfPlaying()
    }

    @IBAction func togglePlayPause(_ sender: UIButton) {
        logInfo("User toggled playback state")
        player.togglePlayPause()
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
