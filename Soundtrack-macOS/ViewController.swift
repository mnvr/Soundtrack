//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Cocoa
import AVFoundation

class ViewController: NSViewController {

    var player: AVAudioPlayer?
    var useRadio: Bool = false

    // MARK: UI

    @IBOutlet weak var playButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // FIXME: This blocks the main queue during launch
        prepareToPlay()
    }

    @IBAction func changeSource(_ sender: NSSegmentedControl) {
        useRadio = sender.selectedSegment == 1
        logInfo("User changed source; use radio = \(useRadio)")

        if let player = player, player.isPlaying {
            pause()
        }
    }

    @IBAction func togglePlayPause(_ sender: NSButton) {
        logInfo("User toggled playback state")

        guard let player = player else {
            return logWarning()
        }

        if player.isPlaying {
            pause()
        } else {
            play()
        }
    }

    private func indicatePlaybackReadiness() {
        DispatchQueue.main.async { [weak self] in
            if let button = self?.playButton {
                button.title = NSLocalizedString("Play", comment: "")
            }
        }
    }

    private func indicatePlayback() {
        DispatchQueue.main.async { [weak self] in
            if let button = self?.playButton {
                button.title = NSLocalizedString("Pause", comment: "")
            }
        }
    }

    // MARK: Player

    private func makePlayer() -> AVAudioPlayer? {
        let player = AudioPlayer.shared.makeExampleLocalPlayer()
        //player?.delegate = self
        return player
    }
    /*
     func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
     logInfo("\(player) decode error: \(error)")
     }

     func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
     logInfo("\(player) finished playing (successfully = \(flag))")
     playbackEnded()
     }
     */

    // MARK: Event Handlers

    private func prepareToPlay() {
        logWarningIf(player != nil)

        player = makePlayer()
        guard let player = player else {
            return
        }
        logInfo("Created \(player)")

        guard player.prepareToPlay() else {
            self.player = nil
            return logWarning("\(player) failed to prepare for playback")
        }

        // FIXME: Conditionally enable this on macOS 10.12
        //logInfo("Registering for receiving remote control events")
        //UIApplication.shared.beginReceivingRemoteControlEvents()

        indicatePlaybackReadiness()
    }

    private func play() {
        guard let player = player else {
            return logWarning()
        }

        logWarningIf(player.isPlaying)

        guard player.play() else {
            return logWarning("Could not start playback")
        }

        indicatePlayback()

        logInfo("Begin playback")
    }

    private func pause() {
        guard let player = player else {
            return logWarning()
        }

        logWarningIf(!player.isPlaying)

        player.pause()

        playbackEnded()
    }

    private func playbackEnded() {
        indicatePlaybackReadiness()

        logInfo("Ended playback")
    }
}
