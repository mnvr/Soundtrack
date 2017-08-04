//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

protocol AudioSession: class {

    func configure()
    func activate() -> Bool
    func deactivate() -> Bool

    var delegate: AudioSessionDelegate? { get set }

}

protocol AudioSessionDelegate: class {

    func audioSessionWasInterrupted(_ audioSession: AudioSession)
    func audioSessionPlaybackShouldPause(_ audioSession: AudioSession)
    func audioSessionPlaybackShouldResume(_ audioSession: AudioSession)

    func audioSessionMediaServicesWereLost(_ audioSession: AudioSession)
    func audioSessionMediaServicesWereReset(_ audioSession: AudioSession)
    
}
