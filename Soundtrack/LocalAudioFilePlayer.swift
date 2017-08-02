//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import AVFoundation

class LocalAudioFilePlayer: NSObject, AudioPlayer, AVAudioPlayerDelegate {

    weak var delegate: AudioPlayerDelegate?

    private let player: AVAudioPlayer

    init?(url: URL, loop: Bool = false) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            logWarning("Could not create audio player: \(error)")
            return nil
        }

        if loop {
            player.numberOfLoops = -1
        }

        if !player.prepareToPlay() {
            logWarning("\(player) failed to prepare for playback")
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
        logInfo("\(player) decode error: \(error)")
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        logInfo("\(player) finished playing (successfully = \(flag))")
        delegate?.audioPlayerDidStop(self, dueToError: flag)
    }
}

extension LocalAudioFilePlayer {

    private static func exampleFileURL() -> URL {
        let fileName = "MN - Going Down.wav"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            fatalError("Could not locate \(fileName) in the main bundle")
        }
        return url
    }

    static func makeExample() -> AudioPlayer? {
        return LocalAudioFilePlayer(url: exampleFileURL(), loop: true)
    }

}
