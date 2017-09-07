//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation
import AVFoundation
import AudioToolbox

// Play an AAC SHOUTcast stream.
//
// An AAC stream has the MIME type "audio/aac", and the data consists
// of ADTS (Audio Data Transport Stream) frames.

class AACShoutcastStreamPlayer: AudioPlayer, ShoutcastStreamDelegate {

    weak var delegate: AudioPlayerDelegate?
    // FIXME: queue

    private let stream: ShoutcastStream

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let adtsParser: ADTSParser


    init(url: URL) {
        stream = ShoutcastStream(url: url, mimeType: "audio/aac")

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)

        adtsParser = ADTSParser(pcmFormat: playerNode.outputFormat(forBus: 0))

        engine.prepare()

        stream.delegate = self
    }

    func play() -> Bool {
        stream.connect()
        return true
    }

    func pause() {
        stream.disconnect()
    }

    var isPlaying: Bool {
        return playerNode.isPlaying
    }

    func shoutcastStreamDidConnect(_ stream: ShoutcastStream) {
        do {
            try engine.start()
        } catch {
            stream.disconnect()
            log.warning(error)
            return
        }
        playerNode.play()
    }

    func shoutcastStreamDidDisconnect(_ stream: ShoutcastStream) {
        playerNode.stop()
        engine.stop()
        delegate?.audioPlayerDidStop(self)
    }

    func shoutcastStream(_ stream: ShoutcastStream, gotTitle title: String) {
        log.info("Got title: \(title)")
    }

    func shoutcastStream(_ stream: ShoutcastStream, gotData data: Data) {
        guard let buffers = adtsParser.parse(data) else {
            stream.disconnect()
            return
        }

        buffers.forEach { playerNode.scheduleBuffer($0) }
    }

}
