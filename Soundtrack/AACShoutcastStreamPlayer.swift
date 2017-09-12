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

    let url: URL
    let queue: DispatchQueue

    weak var delegate: AudioPlayerDelegate?

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private var stream: ShoutcastStream?
    private var adtsParser: ADTSParser?

    init(url: URL, queue: DispatchQueue) {
        self.url = url
        self.queue = queue

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)

        engine.prepare()
    }

    func play() -> Bool {
        connect()
        return true
    }

    /// To maintain the invariant that `isPlaying` returns `true` after
    /// `play` but before `pause`, we track the state of the underlying
    /// audio stream instead of audio playback.
    ///
    /// So `isPlaying` is true without there being any corresponding audio
    /// output in the time window between after when we have initiated a
    /// network connection in response to `play` but before the network
    /// connection has been established.

    var isPlaying: Bool {
        return (stream != nil)
    }

    func pause() {
        guard isPlaying else {
            return log.warning()
        }

        stopAudio()
        disconnect()
    }

    private func connect() {
        adtsParser = ADTSParser(pcmFormat: playerNode.outputFormat(forBus: 0))
        adtsParser?.delegate = self

        stream = ShoutcastStream(url: url, mimeType: "audio/aac", queue: queue)
        stream?.delegate = self
    }

    private func disconnect() {
        stream = nil
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
            disconnect()
            log.warning("Could not start audio playback: \(error)")
        }
    }

    func shoutcastStreamDidDisconnect(_ stream: ShoutcastStream) {
        disconnect()
        stopAudio()
        delegate?.audioPlayerDidFinishPlaying(self)
    }

    func shoutcastStream(_ stream: ShoutcastStream, gotTitle title: String) {
        log.info("Got title: \(title)")
    }

    func shoutcastStream(_ stream: ShoutcastStream, gotData data: Data) {
        guard let adtsParser = adtsParser else {
            return log.warning()
        }

        adtsParser.parse(data)
    }

    func adtsParserDidEncounterError(_ adtsParser: ADTSParser) {
        pause()
    }

    func adtsParser(_ adtsParser: ADTSParser, didParsePCMBuffer buffer: AVAudioPCMBuffer) {
        guard isPlaying else {
            return log.warning()
        }

        playerNode.scheduleBuffer(buffer)
    }

}
