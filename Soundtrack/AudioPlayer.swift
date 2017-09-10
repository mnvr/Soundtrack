//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Dispatch

protocol AudioPlayer: class {

    func play() -> Bool
    func pause()

    var isPlaying: Bool { get }

    /// The serial queue passed into the initializer.
    ///
    /// The delegate methods are guaranteed to be invoked on this queue.
    /// Additionally, the player may internally use the queue to serialize
    /// access to its private state.

    var queue: DispatchQueue { get }

    var delegate: AudioPlayerDelegate? { get set }
    
}

protocol AudioPlayerDelegate: class {

    func audioPlayerDidFinishPlaying(_ audioPlayer: AudioPlayer)

}
