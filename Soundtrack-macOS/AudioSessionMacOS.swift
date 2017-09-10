//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Dispatch

/// A dummy audio session for macOS.
///
/// This allows the playback controller to be platform agnostic.
///
/// Note that this class does not ever call any of the delegate methods.

class AudioSessionMacOS: AudioSession {

    let queue: DispatchQueue

    weak var delegate: AudioSessionDelegate?

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func activate() -> Bool {
        return true
    }

    func deactivate() -> Bool {
        return true
    }

}
