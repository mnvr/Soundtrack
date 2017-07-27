//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import AVFoundation

class AudioPlayer: NSObject, AVAudioPlayerDelegate, AudioSessionDelegate {

    private let queue: DispatchQueue

    var session: AudioSession
    let delegate: AudioPlayerDelegate?
    let makePlayer: () -> AVAudioPlayer?

    var player: AVAudioPlayer?

    init(session: AudioSession, delegate: AudioPlayerDelegate? = nil, make makePlayer: @escaping () -> AVAudioPlayer?) {
        queue = DispatchQueue(label: String(describing: type(of: self)))

        self.session = session
        self.delegate = delegate
        self.makePlayer = makePlayer

        super.init()

        prepare()
    }

    // MARK: API

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

    // MARK: Serially Queued API Implementation

    private func onQueuePrecondition() {
        if #available(iOS 10, OSX 10.12, *) {
            dispatchPrecondition(condition: .onQueue(queue))
        }
    }

    private func prepare_() {
        onQueuePrecondition()

        if player != nil {
            return logWarning()
        }

        session.configure()
        session.delegate = self

        player = makePlayer()

        guard let player = player else {
            return
        }

        player.delegate = self

        logInfo("Created \(player)")

        guard player.prepareToPlay() else {
            self.player = nil
            return logWarning("\(player) failed to prepare for playback")
        }

        delegate?.audioPlayerDidBecomeAvailable(self)
    }

    private func unprepare_() {
        player = nil
        isPlayingAccordingToUs = false

        delegate?.audioPlayerDidBecomeUnavailable(self)
    }

    private func play_() {
        onQueuePrecondition()

        guard let player = player else {
            return logWarning()
        }

        if player.isPlaying {
            return logWarning()
        }

        guard session.activate() else {
            return logWarning()
        }

        guard player.play() else {
            guard session.deactivate() else {
                return logWarning()
            }
            return logWarning("Could not start playback")
        }

        isPlayingAccordingToUs = true

        logInfo("Did begin playback")

        delegate?.audioPlayerDidPlay(self)
    }

    private func pause_() {
        guard let player = player else {
            return logWarning()
        }

        if !player.isPlaying {
            return logWarning()
        }

        player.pause()

        unplay_()
    }

    private func unplay_() {
        onQueuePrecondition()

        isPlayingAccordingToUs = false

        logInfo("Did end playback")

        if !session.deactivate() {
            logWarning()
        }

        delegate?.audioPlayerDidPause(self)
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
            return logWarning()
        }

        if player.isPlaying != isPlayingAccordingToUs {
            logWarning("Playback out of sync (player.isPlaying = \(player.isPlaying), isPlayingAccordingToUs = \(isPlayingAccordingToUs)). We're probably going to trip on some assert soon.")
        }

        if player.isPlaying {
            pause_()
        } else {
            play_()
        }
    }

    // MARK: AVAudioPlayer Delegate

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        logInfo("\(player) decode error: \(error)")
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        logInfo("\(player) finished playing (successfully = \(flag))")
        unplay()
    }

    // MARK: Audio Session Delegate

    func audioSessionWasInterrupted(_ audioSession: AudioSession) {
        isPlayingAccordingToUs = false
        delegate?.audioPlayerDidPause(self)
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

protocol AudioPlayerDelegate {

    func audioPlayerDidBecomeUnavailable(_ audioPlayer: AudioPlayer)
    func audioPlayerDidBecomeAvailable(_ audioPlayer: AudioPlayer)

    func audioPlayerDidPlay(_ audioPlayer: AudioPlayer)
    func audioPlayerDidPause(_ audioPlayer: AudioPlayer)

}

extension AudioPlayer {

    static func makeURLPlayer(url: URL, session: AudioSession, delegate: AudioPlayerDelegate?, loop: Bool = false) -> AudioPlayer {
        return AudioPlayer(session: session, delegate: delegate) {
            let player: AVAudioPlayer

            do {
                player = try AVAudioPlayer(contentsOf: url)
            } catch {
                logWarning("Could not create audio player: \(error)")
                return nil
            }

            if loop {
                player.numberOfLoops = -1
            }

            return player
        }
    }

    private static func exampleFileURL() -> URL {
        let fileName = "MN - Going Down.wav"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            fatalError("Could not locate \(fileName) in the main bundle")
        }
        return url
    }
    
    static func makeExampleFilePlayer(session: AudioSession, delegate: AudioPlayerDelegate?) -> AudioPlayer {
        return makeURLPlayer(url: exampleFileURL(), session: session, delegate: delegate, loop: true)
    }

}
