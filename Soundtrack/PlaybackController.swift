//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

class PlaybackController: NSObject, AudioPlayerDelegate, AudioSessionDelegate {

    private let queue: DispatchQueue

    private var session: AudioSession
    private let makePlayer: () -> AudioPlayer?

    private var player: AudioPlayer?

    private weak var delegate: PlaybackControllerDelegate?

    init(session: AudioSession, delegate: PlaybackControllerDelegate? = nil, make makePlayer: @escaping () -> AudioPlayer?) {
        queue = DispatchQueue(label: String(describing: type(of: self)))

        self.session = session
        self.delegate = delegate
        self.makePlayer = makePlayer

        super.init()

        prepare()
    }

    // MARK: Queue Dispatchers

    private func prepare() {
        queue.async { [weak self] in
            self?.prepare_()
        }
    }

    private func unprepare() {
        queue.async { [weak self] in
            self?.unprepare_()
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

    private func onQueuePrecondition() {
        if #available(iOS 10, OSX 10.12, *) {
            dispatchPrecondition(condition: .onQueue(queue))
        }
    }

    private func prepare_() {
        onQueuePrecondition()

        if player != nil {
            return log.warning()
        }

        session.configure()
        session.delegate = self

        player = makePlayer()
        player?.delegate = self

        guard let player = player else {
            return log.warning("Failed to create player")
        }

        log.info("Created \(player)")

        delegate?.playbackControllerDidBecomeAvailable(self)
    }

    private func unprepare_() {
        player = nil
        isPlayingAccordingToUs = false

        delegate?.playbackControllerDidBecomeUnavailable(self)
    }

    private func play_() {
        onQueuePrecondition()

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

        if !session.deactivate() {
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

    func audioPlayerDidStop(_ audioPlayer: AudioPlayer, dueToError: Bool) {
        log.info("\(player) stopped (dueToError = \(dueToError))")
        unplay()
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
        unprepare()
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

