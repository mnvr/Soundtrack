//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

class AudioSessionMacOS: AudioSession {

    static let shared = AudioSessionMacOS()

    var delegate: AudioSessionDelegate?

    func configure() {
    }

    func activate() -> Bool {
        return true
    }

    func deactivate() -> Bool {
        return true
    }

}
