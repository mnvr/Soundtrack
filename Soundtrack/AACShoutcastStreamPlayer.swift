//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation
import AVFoundation
import AudioToolbox

/// Play an AAC SHOUTcast stream.
///
/// An AAC stream has the MIME type "audio/aac", and the data consists
/// of ADTS (Audio Data Transport Stream) frames.

class AACShoutcastStreamPlayer: AudioPlayer, ShoutcastStreamDelegate {

    let queue: DispatchQueue

    weak var delegate: AudioPlayerDelegate?

    private let stream: ShoutcastStream

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let adtsParser: ADTSParser

    init(url: URL, queue: DispatchQueue) {
        self.queue = queue

        stream = ShoutcastStream(url: url, mimeType: "audio/aac", queue: queue)

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
        stopAudio()
        stream.disconnect()
    }

    var isPlaying: Bool {
        return engine.isRunning
    }

    func shoutcastStreamDidConnect(_ stream: ShoutcastStream) {
        do {
            try startAudio()
        } catch {
            stream.disconnect()
            log.warning(error)
        }
    }

    private func startAudio() throws {
        try engine.start()
        playerNode.play()
    }

    private func stopAudio() {
        playerNode.stop()
        engine.stop()
    }

    func shoutcastStreamDidDisconnect(_ stream: ShoutcastStream) {
        if isPlaying { // the stream disconnected on its own
            stopAudio()
            delegate?.audioPlayerDidFinishPlaying(self)
        }
    }

    func shoutcastStream(_ stream: ShoutcastStream, gotTitle title: String) {
        log.info("Got title: \(title)")
    }

    func shoutcastStream(_ stream: ShoutcastStream, gotData data: Data) {
        guard let buffers = adtsParser.parse(data) else {
            return pause()
        }

        buffers.forEach { playerNode.scheduleBuffer($0) }
    }

}
