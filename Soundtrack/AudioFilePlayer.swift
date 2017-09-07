//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import AVFoundation

class AudioFilePlayer: NSObject, AudioPlayer, AVAudioPlayerDelegate {

    weak var delegate: AudioPlayerDelegate?

    private let player: AVAudioPlayer

    init?(url: URL, loop: Bool = false) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            log.warning("Could not create audio player: \(error)")
            return nil
        }

        if loop {
            player.numberOfLoops = -1
        }

        if !player.prepareToPlay() {
            log.warning("\(player) failed to prepare for playback")
            return nil
        }

        super.init()

        player.delegate = self
    }

    func play() -> Bool {
        return player.play()
    }

    func pause() {
        player.pause()
    }

    var isPlaying: Bool {
        return player.isPlaying
    }

    // MARK: Delegate

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        log.info("\(player) decode error: \(error)")
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        log.info("\(player) finished playing (successfully = \(flag))")
        delegate?.audioPlayerDidStop(self)
    }
}
