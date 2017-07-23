//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import AVFoundation

class AudioPlayer {
    static let shared = AudioPlayer()

    func makeExampleLocalPlayer() -> AVAudioPlayer? {
        let shouldLoop = true
        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: exampleFileURL())
        } catch {
            logWarning("Could not create audio player: \(error)")
            return nil
        }
        if shouldLoop {
            player.numberOfLoops = -1
        }
        return player
    }

    private func exampleFileURL() -> URL {
        let fileName = "MN - Going Down.wav"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            fatalError("Could not locate \(fileName) in the main bundle")
        }
        return url
    }
}
