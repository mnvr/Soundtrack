// ViewController.swift
// Soundtrack iOS
//
// Copyright (c) 2017 Manav Rathi
//
// Apache License, Version 2.0 (see LICENSE)

import UIKit
import AVFoundation

class ViewController: UIViewController, AVAudioPlayerDelegate {

    // MARK: Properties

    @IBOutlet weak var playButton: UIButton!

    var audioSession: AVAudioSession?
    var player: AVAudioPlayer?

    var wasPlaying: Bool = false

    var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?

    // MARK: User Interface

    override func viewDidLoad() {
        super.viewDidLoad()

        observeAudioSessionNotifications()
        prepareForPlayback()
    }

    @IBAction func queryAudioSession() {
        guard let audioSession = audioSession else {
            return logWarning()
        }

        doQueryAudioSession(audioSession)
    }

    @IBAction func togglePlayback() {
        logInfo("User toggled playback state")

        guard let player = player else {
            return logWarning("Ignoring play/pause toggle because the player is not available. This should only happen during a media services loss.")
        }

        if player.isPlaying {
            pause()
        } else {
            play()
        }
    }

    private func indicatePlaybackReadiness() {
        DispatchQueue.main.async { [weak self] in
            self?.playButton.setTitle("Play", for: .normal)
        }
    }

    private func indicatePlayback() {
        DispatchQueue.main.async { [weak self] in
            self?.playButton.setTitle("Pause", for: .normal)
        }
    }

    // MARK: Audio Session

    func doQueryAudioSession(_ audioSession: AVAudioSession, abridged: Bool = false) {
        logInfo("Querying \(audioSession)...")

        logInfo("Current audio session category: \(audioSession.category)")
        logInfo("Current audio session mode: \(audioSession.mode)")
        logInfo("Audio session category options: \(audioSession.categoryOptions)")

        if abridged {
            return
        }

        logInfo("Current route: \(audioSession.currentRoute)")

        logInfo("Available output data sources for the current route: \(audioSession.outputDataSources)")
        logInfo("Currently selected output data source: \(audioSession.outputDataSource)")

        logInfo("Maximum number of output channels available for the current route: \(audioSession.maximumOutputNumberOfChannels)")
        logInfo("Current number of output channels: \(audioSession.outputNumberOfChannels)")

        logInfo("System wide audio output volume set by the user: \(audioSession.outputVolume)")

        let ms = { Int($0 * 1000.0) }
        logInfo("Output latency (ms): \(ms(audioSession.outputLatency))")
        logInfo("I/O buffer duration (ms): \(ms(audioSession.ioBufferDuration))")

        logInfo("Sample rate (Hz): \(audioSession.sampleRate)")

        logInfo("Is another app currently playing (any) audio? \(audioSession.isOtherAudioPlaying)")
        logInfo("Is another app currently playing (primary) audio? \(audioSession.secondaryAudioShouldBeSilencedHint)")
    }

    private func observeAudioSessionNotifications() {
        logInfo("Attaching observers for audio session notifications")

        // The documentation states that these notifications should be
        // delivered on the main thread. However, it was observed when
        // running on a device (iPhone 4S, iOS 9.3) that they are instead
        // delivered on a thread named "AVAudioSession Notify Thread".

        let observe = {
            NotificationCenter.default.addObserver(self, selector: $1, name: $0, object: nil)
        }

        observe(.AVAudioSessionInterruption, #selector(audioSessionInterruption(_:)))
        observe(.AVAudioSessionRouteChange, #selector(audioSessionRouteChange(_:)))
        observe(.AVAudioSessionMediaServicesWereLost, #selector(audioSessionMediaServicesWereLost(_:)))
        observe(.AVAudioSessionMediaServicesWereReset, #selector(audioSessionMediaServicesWereReset(_:)))
    }

    private func configureAudioSession(_ audioSession: AVAudioSession) {
        doQueryAudioSession(audioSession, abridged: true)

        logInfo("Configuring \(audioSession) for music playback")
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            logWarning("Could not set audio session category: \(error)")
            return
        }

        logInfo("Re-querying audio session post configuration...")
        doQueryAudioSession(audioSession)
    }

    private func activateAudioSession(_ audioSession: AVAudioSession) -> Bool {
        do {
            try audioSession.setActive(true)
        } catch {
            logWarning(error)
            return false
        }
        return true
    }

    private func deactivateAudioSession(_ audioSession: AVAudioSession) -> Bool {
        do {
            try audioSession.setActive(false, with: .notifyOthersOnDeactivation)
        } catch {
            logWarning(error)
            return false
        }
        return true
    }

    // MARK: Audio Session Notifications

    func audioSessionInterruption(_ notification: Notification) {
        logInfo("Audio session interruption: \(notification)")

        guard let type: AVAudioSessionInterruptionType = notification.enumForKey( AVAudioSessionInterruptionTypeKey) else {
            return logWarning()
        }

        switch type {
        case .began:
            logInfo("Interruption began")
            if wasPlaying {
                indicatePlaybackReadiness()
                endBackgroundTask()
            }

        case .ended:
            logInfo("Interruption ended")

            guard let options: AVAudioSessionInterruptionOptions = notification.enumForKey(AVAudioSessionInterruptionOptionKey) else {
                break
            }

            logDebug("Interruption options: \(options)")
            if options.contains(.shouldResume) {
                logInfo("Interruption options mention that playback should resume")
                if wasPlaying {
                    playAfterResumingFromInterruption()
                }
            }
        }
    }

    func audioSessionRouteChange(_ notification: Notification) {
        logInfo("Audio route changed: \(notification)")

        if let reason: AVAudioSessionRouteChangeReason = notification.enumForKey(AVAudioSessionRouteChangeReasonKey) {

            logDebug("Route change reason: \(reason.rawValue)")

            if reason == .oldDeviceUnavailable {
                // e.g. headset was unplugged.
                logInfo("Route changed because old device became unavailable")

                if wasPlaying {
                    pause()
                }
            }
        }
    }

    func audioSessionMediaServicesWereLost(_ notification: Notification) {
        logInfo("Media services were lost: \(notification)")

        player = nil
        audioSession = nil

        indicatePlaybackReadiness()
    }

    func audioSessionMediaServicesWereReset(_ notification: Notification) {
        logInfo("Media services were restarted: \(notification)")

        prepareForPlayback()
    }

    func playAfterResumingFromInterruption() {

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
        let fileName = "MN - Going Down.wav"
        let shouldLoop = true

        let player: AVAudioPlayer
        guard let exampleFileURL = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            logWarning("Could not locate \(fileName) in the main bundle")
            return nil
        }
        do {
            player = try AVAudioPlayer(contentsOf: exampleFileURL)
        } catch {
            logWarning("Could not create audio player: \(error)")
            return nil
        }
        player.delegate = self
        if shouldLoop {
            player.numberOfLoops = -1
        }
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
        logWarningIf(audioSession != nil)
        logWarningIf(player != nil)

        audioSession = AVAudioSession.sharedInstance()
        guard let audioSession = audioSession else {
            fatalError()
        }
        logInfo("Using \(audioSession)")

        configureAudioSession(audioSession)

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
        guard let audioSession = audioSession else {
            return logWarning()
        }

        guard let player = player else {
            return logWarning()
        }

        guard activateAudioSession(audioSession) else {
            return
        }

        logWarningIf(player.isPlaying)

        guard player.play() else {
            _ = deactivateAudioSession(audioSession)
            return logWarning("Could not start playback")
        }

        beginBackgroundTask()

        indicatePlayback()

        wasPlaying = true

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
        guard let audioSession = audioSession else {
            return logWarning()
        }

        _ = deactivateAudioSession(audioSession)

        indicatePlaybackReadiness()

        wasPlaying = false

        endBackgroundTask()

        logInfo("Ended playback")
    }

}
