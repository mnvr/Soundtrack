//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

protocol AudioPlayer {

    func play() -> Bool
    func pause()

    var isPlaying: Bool { get }

    var delegate: AudioPlayerDelegate? { get set }
    
}

protocol AudioPlayerDelegate: class {

    func audioPlayerDidStop(_ audioPlayer: AudioPlayer, dueToError: Bool)

}
