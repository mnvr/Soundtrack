//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import AVFoundation

class AudioPlayer: NSObject, AVAudioPlayerDelegate {

    private let queue: DispatchQueue

    let url: URL
    let delegate: AudioPlayerDelegate?
    let configure: ((AVAudioPlayer) -> Void)?

    var player: AVAudioPlayer?

    init(url: URL, delegate: AudioPlayerDelegate? = nil, configure: ((AVAudioPlayer) -> Void)? = nil) {
        queue = DispatchQueue(label: String(describing: type(of: self)))

        self.url = url
        self.delegate = delegate
        self.configure = configure

        super.init()

        prepareToPlay()
    }

    // MARK: API

    private func prepareToPlay() {
        queue.async { [weak self] in
            self?.prepareToPlay_()
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

    private func prepareToPlay_() {
        onQueuePrecondition()

        logWarningIf(player != nil)

        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            return logWarning("Could not create audio player: \(error)")
        }

        guard let player = player else {
            return
        }

        player.delegate = self

        if let configure = configure {
            configure(player)
        }

        logInfo("Created \(player)")

        guard player.prepareToPlay() else {
            self.player = nil
            return logWarning("\(player) failed to prepare for playback")
        }

        // FIXME: Conditionally enable this on macOS 10.12
        //logInfo("Registering for receiving remote control events")
        //UIApplication.shared.beginReceivingRemoteControlEvents()

        delegate?.audioPlayerDidBecomeAvailable(self)
    }

    private func play_() {
        onQueuePrecondition()

        guard let player = player else {
            return logWarning()
        }

        logWarningIf(player.isPlaying)

        guard player.play() else {
            return logWarning("Could not start playback")
        }

        logInfo("Begin playback")
        delegate?.audioPlayerDidPlay(self)
    }

    private func pause_() {
        guard let player = player else {
            return logWarning()
        }

        logWarningIf(!player.isPlaying)

        player.pause()

        playbackEnded()
    }

    private func playbackEnded() {
        logInfo("Ended playback")
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
        playbackEnded()
    }

}

protocol AudioPlayerDelegate {

    func audioPlayerDidBecomeUnavailable(_ audioPlayer: AudioPlayer)
    func audioPlayerDidBecomeAvailable(_ audioPlayer: AudioPlayer)

    func audioPlayerDidPlay(_ audioPlayer: AudioPlayer)
    func audioPlayerDidPause(_ audioPlayer: AudioPlayer)

}

extension AudioPlayer {

    private static func exampleFileURL() -> URL {
        let fileName = "MN - Going Down.wav"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            fatalError("Could not locate \(fileName) in the main bundle")
        }
        return url
    }

    static func makeExampleFilePlayer(delegate: AudioPlayerDelegate?) -> AudioPlayer {
        return AudioPlayer(url: exampleFileURL(), delegate: delegate) { avAudioPlayer in
            avAudioPlayer.numberOfLoops = -1
        }
    }
}
