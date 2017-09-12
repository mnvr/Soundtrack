//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

class PlaybackController: NSObject, AudioPlayerDelegate, AudioSessionDelegate {

    private let queue: DispatchQueue

    private weak var delegate: PlaybackControllerDelegate?

    typealias MakeSession = (_ queue: DispatchQueue) -> AudioSession?
    private let makeSession: MakeSession
    private var session: AudioSession?

    typealias MakePlayer = (_ queue: DispatchQueue) -> AudioPlayer?
    private let makePlayer: MakePlayer
    private var player: AudioPlayer?

    init(delegate: PlaybackControllerDelegate? = nil, makeSession: @escaping MakeSession, makePlayer: @escaping MakePlayer) {
        queue = DispatchQueue(label: "Audio Subsytem")

        self.delegate = delegate

        self.makeSession = makeSession
        self.makePlayer = makePlayer

        super.init()

        prepare()
    }

    // MARK: Queue Forwarders

    private func prepare() {
        queue.async { [weak self] in
            self?.prepare_()
        }
    }

    func play() {
        queue.async { [weak self] in
            self?.play_()
        }
    }

    func pause() {
        queue.async { [weak self] in
            self?.pause_()
        }
    }

    private func unplay() {
        queue.async { [weak self] in
            self?.unplay_()
        }
    }

    func pauseIfPlaying() {
        queue.async { [weak self] in
            self?.pauseIfPlaying_()
        }
    }

    func togglePlayPause() {
        queue.async { [weak self] in
            self?.togglePlayPause_()
        }
    }

    // MARK: Serially Queued Implementation

    func onQueuePrecondition() {
        if #available(iOS 10, OSX 10.12, *) {
            dispatchPrecondition(condition: .onQueue(queue))
        }
    }

    private func prepare_() {
        onQueuePrecondition()

        if player != nil {
            return log.warning()
        }

        session = makeSession(queue)
        guard let session = session else { fatalError() }
        session.delegate = self

        player = makePlayer(queue)
        player?.delegate = self

        guard let player = player else {
            return log.warning("Failed to create player")
        }

        log.debug("Created \(player)")

        delegate?.playbackControllerDidBecomeAvailable(self)
    }

    private func stopPlayback() {
        player = nil
        isPlayingAccordingToUs = false

        delegate?.playbackControllerDidBecomeUnavailable(self)
    }

    private func play_() {
        onQueuePrecondition()

        guard let session = session else {
            return log.warning()
        }

        guard let player = player else {
            return log.warning()
        }

        if player.isPlaying {
            return log.warning()
        }

        guard session.activate() else {
            return log.warning()
        }

        guard player.play() else {
            guard session.deactivate() else {
                return log.warning()
            }
            return log.warning("Could not start playback")
        }

        isPlayingAccordingToUs = true

        log.info("Did begin playback")

        delegate?.playbackControllerDidPlay(self)
    }

    private func pause_() {
        onQueuePrecondition()

        guard let player = player else {
            return log.warning()
        }

        if !player.isPlaying {
            return log.warning()
        }

        player.pause()

        unplay_()
    }

    private func unplay_() {
        onQueuePrecondition()

        isPlayingAccordingToUs = false

        log.info("Did end playback")

        if session?.deactivate() != true {
            log.warning()
        }

        delegate?.playbackControllerDidPause(self)
    }

    private func pauseIfPlaying_() {
        onQueuePrecondition()

        if let player = player, player.isPlaying {
            pause_()
        }
    }

    private func togglePlayPause_() {
        onQueuePrecondition()

        guard let player = player else {
            return log.warning()
        }

        if player.isPlaying != isPlayingAccordingToUs {
            log.warning("Playback out of sync (player.isPlaying = \(player.isPlaying), isPlayingAccordingToUs = \(isPlayingAccordingToUs)). We're probably going to trip on some assert soon.")
        }

        if player.isPlaying {
            pause_()
        } else {
            play_()
        }
    }

    // MARK: AudioPlayer Delegate

    func audioPlayerDidFinishPlaying(_ audioPlayer: AudioPlayer) {
        onQueuePrecondition()

        log.debug("\(player) finished playing")
        unplay_()
    }

    // MARK: Audio Session Delegate

    func audioSessionWasInterrupted(_ audioSession: AudioSession) {
        isPlayingAccordingToUs = false
        delegate?.playbackControllerDidPause(self)
    }

    func audioSessionPlaybackShouldPause(_ audioSession: AudioSession) {
        pause()
    }

    func audioSessionPlaybackShouldResume(_ audioSession: AudioSession) {
        play()
    }

    func audioSessionMediaServicesWereLost(_ audioSession: AudioSession) {
        // We do not let go of the session at this time because it will
        // subsequently tell us when the reset completes (in the media
        // services were reset notification below); and that point, we
        // let go of the current session and create a new one.

        stopPlayback()
    }

    func audioSessionMediaServicesWereReset(_ audioSession: AudioSession) {
        prepare()
    }

    // MARK: WORKAROUND NEEDED
    //
    // Sometimes, AVAudioPlayer does not produce any sound when resuming
    // playback after an interruption, even though the play method does
    // not return any error.
    //
    // In some such cases, the isPlaying property changes back to false on
    // its own, and gets out of sync with our state machine.
    //
    // We use an copy of the property to detect when this happens. We don't
    // yet have a workaround in place to handle this.
    //
    // Observed on: iOS 9.3, iPhone 4S
    //
    // Steps to reproduce:
    //
    // - Set up an timer.
    // - Return to app and start playback.
    // - Press OK on the timer alert.
    //

    var isPlayingAccordingToUs: Bool = false
}

protocol PlaybackControllerDelegate: class {

    func playbackControllerDidBecomeUnavailable(_ playbackController: PlaybackController)
    func playbackControllerDidBecomeAvailable(_ playbackController: PlaybackController)

    func playbackControllerDidPlay(_ playbackController: PlaybackController)
    func playbackControllerDidPause(_ playbackController: PlaybackController)
    
}

