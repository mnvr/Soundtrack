//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AudioSessionDelegate, AVAudioPlayerDelegate {

    // MARK: Properties

    @IBOutlet weak var playButton: UIButton!

    let audioSession = AudioSession.shared
    var player: AVAudioPlayer?

    var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?

    // MARK: User Interface

    override func viewDidLoad() {
        super.viewDidLoad()

        prepareForPlayback()
    }

    @IBAction func queryAudioSession() {
        audioSession.query()
    }

    @IBAction func togglePlayback() {
        logInfo("User toggled playback state")

        guard let player = player else {
            return logWarning("Ignoring play/pause toggle because the player is not available; this should only happen during a media services loss.")
        }

        if player.isPlaying {
            pause()
        } else {
            play()
        }
    }

    private func indicatePlaybackReadiness() {
        DispatchQueue.main.async { [weak self] in
            self?.playButton.setTitle(NSLocalizedString("Play", comment: ""), for: .normal)
        }
    }

    private func indicatePlayback() {
        DispatchQueue.main.async { [weak self] in
            self?.playButton.setTitle(NSLocalizedString("Pause", comment: ""), for: .normal)
        }
    }

    // MARK: Audio Session Delegate

    func audioSessionWasInterrupted(_ audioSession: AudioSession) {
        indicatePlaybackReadiness()
        endBackgroundTask()
    }

    func audioSessionPlaybackShouldPause(_ audioSession: AudioSession) {
        pause()
    }

    func audioSessionPlaybackMayResume(_ audioSession: AudioSession) {
        playAfterResumingFromInterruption()
    }

    func audioSessionMediaServicesWereLost(_ audioSession: AudioSession) {
        player = nil

        indicatePlaybackReadiness()
    }

    func audioSessionMediaServicesWereReset(_ audioSession: AudioSession) {
        prepareForPlayback()
    }

    private func playAfterResumingFromInterruption() {

        // Sometimes, AVAudioPlayer does not produce any sound output when
        // we resume playback after an interruption. None of the API calls
        // respond with an error.
        //
        // This was observed on device (iOS 9.3):
        // - Set up an timer
        // - Return to app and start playback
        // - Let the timer fire. The application stays in the foreground.
        // - Press OK on the timer alert. The application becomes active
        //   again, and playback resumes, but there is no audio output.
        //
        // There are numerous reports of similar buggy behaviour online.
        //
        // This is a bunch of voodoo to ensure that doesn't happen to us. It
        // doesn't always work, but it does reduce the frequency of the
        // buggy behaviour.

        let deadline = DispatchTime.now() + 0.4
        DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
            self?.becomeFirstResponder()
            self?.play()
        }

    }

    // MARK: Background Task

    private func beginBackgroundTask() {
        logWarningIf(backgroundTaskIdentifier != nil)
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask {
            logWarning("We were asked to relinquish our background task before playback ended")
        }
        logInfo("Began background task with identifier \(backgroundTaskIdentifier)")

    }

    private func endBackgroundTask() {
        guard let backgroundTaskIdentifier = backgroundTaskIdentifier else {
            return logWarning()
        }

        logInfo("Ending background task with identifier \(backgroundTaskIdentifier)")
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)

        self.backgroundTaskIdentifier = nil
    }

    // MARK: Player

    private func makePlayer() -> AVAudioPlayer? {
        let player = AudioPlayer.shared.makeExampleLocalPlayer()
        player?.delegate = self
        return player
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        logInfo("\(player) decode error: \(error)")
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        logInfo("\(player) finished playing (successfully = \(flag))")
        playbackEnded()
    }

    // MARK: Event Handlers

    private func prepareForPlayback() {
        logWarningIf(player != nil)

        audioSession.configure()
        audioSession.delegate = self

        player = makePlayer()
        guard let player = player else {
            return
        }
        logInfo("Created \(player)")

        guard player.prepareToPlay() else {
            self.player = nil
            return logWarning("\(player) failed to prepare for playback")
        }

        logInfo("Registering for receiving remote control events")
        UIApplication.shared.beginReceivingRemoteControlEvents()

        indicatePlaybackReadiness()
    }

    private func play() {
        guard let player = player else {
            return logWarning()
        }

        guard audioSession.activate() else {
            return
        }

        logWarningIf(player.isPlaying)

        guard player.play() else {
            _ = audioSession.deactivate()
            return logWarning("Could not start playback")
        }

        beginBackgroundTask()

        indicatePlayback()

        audioSession.wasPlaying = true

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
        _ = audioSession.deactivate()

        indicatePlaybackReadiness()

        audioSession.wasPlaying = false

        endBackgroundTask()

        logInfo("Ended playback")
    }

}
