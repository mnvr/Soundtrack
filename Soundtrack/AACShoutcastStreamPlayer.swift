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

class AACShoutcastStreamPlayer: AudioPlayer, ShoutcastStreamDelegate, ADTSParserDelegate {

    let queue: DispatchQueue

    weak var delegate: AudioPlayerDelegate?

    private let stream: ShoutcastStream

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private var adtsParser: ADTSParser?

    init(url: URL, queue: DispatchQueue) {
        self.queue = queue

        stream = ShoutcastStream(url: url, mimeType: "audio/aac", queue: queue)

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)

        engine.prepare()

        stream.delegate = self
    }

    func play() -> Bool {
        startStream()
        return true
    }

    var isPlaying: Bool {
        return (adtsParser != nil)
    }

    func pause() {
        guard isPlaying else {
            return log.warning()
        }

        stopAudio()
        stopStream()
    }

    private func startStream() {
        adtsParser = ADTSParser(pcmFormat: playerNode.outputFormat(forBus: 0))
        adtsParser!.delegate = self
        stream.connect()
    }

    private func stopStream() {
        stream.disconnect()
        adtsParser = nil
    }

    private func startAudio() throws {
        try engine.start()
        playerNode.play()
    }

    private func stopAudio() {
        playerNode.stop()
        engine.stop()
    }

    func shoutcastStreamDidConnect(_ stream: ShoutcastStream) {
        do {
            try startAudio()
        } catch {
            stopStream()
            log.warning(error)
        }
    }

    func shoutcastStreamDidDisconnect(_ stream: ShoutcastStream) {
        if isPlaying { // the stream disconnected on its own
            stopAudio()
            adtsParser = nil

            delegate?.audioPlayerDidFinishPlaying(self)
        }
    }

    func shoutcastStream(_ stream: ShoutcastStream, gotTitle title: String) {
        log.info("Got title: \(title)")
    }

    func shoutcastStream(_ stream: ShoutcastStream, gotData data: Data) {
        guard let adtsParser = adtsParser else {
            // FIXME This happens
            //return log.warning()
            return
        }
        adtsParser.parse(data)
    }

    func adtsParserDidEncounterError(_ adtsParser: ADTSParser) {
        return pause()
    }

    func adtsParser(_ adtsParser: ADTSParser, didParsePCMBuffer buffer: AVAudioPCMBuffer) {
        guard isPlaying else {
            return log.warning()
        }

        playerNode.scheduleBuffer(buffer)
    }

}
