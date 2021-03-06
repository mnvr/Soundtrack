//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

/// The funnel between the UI and the rest of the audio hierarchy.

class AudioController: NSObject, StreamPlayer, AudioSessionDelegate, StreamPlayerDelegate, RemoteCommandCenterDelegate {

    let url: URL
    weak var delegate: (AudioControllerDelegate & StreamPlayerDelegate)?
    let delegateQueue: DispatchQueue
    let makeSession: (_ queue: DispatchQueue) -> AudioSession

    private let queue: DispatchQueue
    private var session: AudioSession?
    private var player: AACShoutcastStreamPlayer?
    private var remoteCommandCenter: RemoteCommandCenter?
    private var nowPlayingInfoCenter: NowPlayingInfoCenter?

    private var canPause: Bool = false
    private var isSessionActive: Bool = false

    init(url: URL, delegate: (AudioControllerDelegate & StreamPlayerDelegate)?, delegateQueue: DispatchQueue, makeSession: @escaping (_ queue: DispatchQueue) -> AudioSession) {

        self.url = url
        self.delegate = delegate
        self.delegateQueue = delegateQueue
        self.makeSession = makeSession

        queue = DispatchQueue(label: "Soundtrack Audio")

        super.init()

        queue.async { [weak self] in
            self?.reset()
        }
    }

    // MARK: API

    /// Toggle the state of the controller.
    ///
    /// This method is "safe" to be invoked at any time.
    ///
    /// If audio is paused, initiate playback.
    /// If audio is playing, initiate a pause.
    /// In other scenarios, like if playback is unavailable, ignore.

    func playPause() {
        queue.async { [weak self] in
            self?.whatever()
        }
    }

    // MARK: -

    func onQueuePrecondition() {
        if #available(iOS 10, OSX 10.12, *) {
            dispatchPrecondition(condition: .onQueue(queue))
        }
    }

    private var isAvailable: Bool  {
        return player != nil
    }

    private func reset() {
        onQueuePrecondition()

        precondition(!isAvailable)

        session = makeSession(queue)
        session!.delegate = self
        isSessionActive = false

        player = AACShoutcastStreamPlayer(url: url, delegateQueue: queue)
        player!.delegate = self

        remoteCommandCenter = RemoteCommandCenter()
        remoteCommandCenter?.delegate = self

        nowPlayingInfoCenter = NowPlayingInfoCenter()

        audioControllerDidBecomeAvailable()
    }

    private func discardPlayer() {
        onQueuePrecondition()

        precondition(isAvailable)

        player = nil
        canPause = false

        audioControllerDidBecomeUnavailable()
    }

    private func whatever() {
        onQueuePrecondition()

        if isAvailable {
            if canPause {
                pause()
            } else {
                play()
            }
        }
    }

    private func play() {
        onQueuePrecondition()

        guard session!.activate() else {
            return log.warning()
        }
        isSessionActive = true

        player!.play()
        canPause = true

        audioControllerWillStartPlayback()
    }

    private func pause() {
        onQueuePrecondition()

        player!.pause()
        canPause = false

        audioControllerWillStopPlayback()
    }

    // MARK: Delegate

    private func audioControllerDidBecomeAvailable() {
        delegateQueue.async { [weak self] in
            if let strongSelf = self {
                strongSelf.delegate?.audioControllerDidBecomeAvailable(strongSelf)
            }
        }
    }

    private func audioControllerDidBecomeUnavailable() {
        delegateQueue.async { [weak self] in
            if let strongSelf = self {
                strongSelf.delegate?.audioControllerDidBecomeUnavailable(strongSelf)
            }
        }
    }

    private func audioControllerWillStartPlayback() {
        delegateQueue.async { [weak self] in
            if let strongSelf = self {
                strongSelf.delegate?.audioControllerWillStartPlayback(strongSelf)
            }
        }
    }

    private func audioControllerWillStopPlayback() {
        delegateQueue.async { [weak self] in
            if let strongSelf = self {
                strongSelf.delegate?.audioControllerWillStopPlayback(strongSelf)
            }
        }
    }

    // MARK: Stream Player

    func streamPlayerDidStartPlayback(_ streamPlayer: StreamPlayer) {
        log.info("Playback did start")

        delegateQueue.async { [weak self] in
            if let strongSelf = self {
                strongSelf.delegate?.streamPlayerDidStartPlayback(strongSelf)
            }
        }
    }

    func streamPlayerDidStopPlayback(_ streamPlayer: StreamPlayer) {
        if isSessionActive {
            if session?.deactivate() != true {
                log.warning()
            }
            isSessionActive = false
        }

        if canPause {
            canPause = false

            audioControllerWillStopPlayback()
        }

        nowPlayingInfoCenter?.clear()

        log.info("Playback stopped")

        delegateQueue.async { [weak self] in
            if let strongSelf = self {
                strongSelf.delegate?.streamPlayerDidStopPlayback(strongSelf)
            }
        }
    }

    func streamPlayer(_ streamPlayer: StreamPlayer, didChangeSong title: String) {
        log.info("Song: \(title)")

        nowPlayingInfoCenter?.setTitle(title)

        delegateQueue.async { [weak self] in
            if let strongSelf = self {
                strongSelf.delegate?.streamPlayer(strongSelf, didChangeSong: title)
            }
        }
    }

    // MARK: Audio Session

    func audioSessionWasInterrupted(_ audioSession: AudioSession) {
        isSessionActive = false
        pause()
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

        discardPlayer()
    }

    func audioSessionMediaServicesWereReset(_ audioSession: AudioSession) {
        reset()
    }

    // MARK: Remote Command Center

    func remoteCommandCenterDidTogglePlayPause(_ remoteCommandCenter: RemoteCommandCenter) {
        playPause()
    }

}

protocol AudioControllerDelegate: class {

    func audioControllerDidBecomeUnavailable(_ audioController: AudioController)
    func audioControllerDidBecomeAvailable(_ audioController: AudioController)

    /// This method is invoked when the playback is initiated potentially
    /// without the knowledge of the delegate.

    func audioControllerWillStartPlayback(_ audioController: AudioController)

    /// This method is invoked when the playback is initiated potentially
    /// without the knowledge of the delegate.

    func audioControllerWillStopPlayback(_ audioController: AudioController)

}

