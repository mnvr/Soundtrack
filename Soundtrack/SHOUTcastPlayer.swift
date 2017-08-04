//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

class StreamDelegate: SHOUTcastStreamDelegate {

    func shoutcastStream(_ stream: SHOUTcastStream, gotTitle title: String) {
        log.info("Got title: \(title)")
    }

    func shoutcastStream(_ stream: SHOUTcastStream, gotData data: Data) {
        log.info("Got \(data.count) bytes")
    }

}

class SHOUTcastPlayer {
    private let aacMimeType = "audio/aac"

    private let stream: SHOUTcastStream
    private let delegate = StreamDelegate()

    init(url: URL) {
        stream = SHOUTcastStream(url: url, mimeType: aacMimeType)
        stream.delegate = delegate
    }

    func connect() {
        stream.connect()

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0) { [weak self] in
            // WIP Test disconnect
            self?.stream.disconnect()
        }
    }
}
