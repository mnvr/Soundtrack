//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

protocol AudioSession: class {

    func activate() -> Bool
    func deactivate() -> Bool

    /// The serial queue passed into the initializer.
    ///
    /// The delegate methods are guaranteed to be invoked on this queue.
    /// Additionally, the player may internally use the queue to serialize
    /// access to its private state.

    var queue: DispatchQueue { get }

    var delegate: AudioSessionDelegate? { get set }

}

protocol AudioSessionDelegate: class {

    func audioSessionWasInterrupted(_ audioSession: AudioSession)
    func audioSessionPlaybackShouldPause(_ audioSession: AudioSession)
    func audioSessionPlaybackShouldResume(_ audioSession: AudioSession)

    func audioSessionMediaServicesWereLost(_ audioSession: AudioSession)

    /// Now is a good time to let go of the audioSession and create a new one.
    
    func audioSessionMediaServicesWereReset(_ audioSession: AudioSession)
    
}
