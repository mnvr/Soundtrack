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

class AACShoutcastStreamPlayer: StreamPlayer, ShoutcastStreamDelegate, ADTSParserDelegate {

    let url: URL
    let delegateQueue: DispatchQueue

    weak var delegate: StreamPlayerDelegate?

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private var stream: ShoutcastStream?
    private var adtsParser: ADTSParser?

    private var activeVolumeRamp: VolumeRamp?

    /// - Parameter url: The URL of the SHOUTcast stream server that
    ///   emits an AAC audio stream.
    ///
    /// - Parameter delegateQueue: A serial queue on which the delegate
    ///   methods will be invoked.

    init(url: URL, delegateQueue: DispatchQueue) {
        self.url = url
        self.delegateQueue = delegateQueue

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)

        engine.prepare()
    }

    func play() {
        connect()
    }

    func pause() {
        fadeOut { [weak self] in
            self?.stopPlayback()
            self?.disconnect()
        }
    }

    private func connect() {
        adtsParser = ADTSParser(pcmFormat: playerNode.outputFormat(forBus: 0))
        adtsParser?.delegate = self

        stream = ShoutcastStream(url: url, mimeType: "audio/aac", delegate: self, delegateQueue: delegateQueue)
    }
    
    private func disconnect() {
        stream = nil
        adtsParser = nil
    }

    private func startPlayback() throws {
        try engine.start()
        playerNode.volume = 0
        playerNode.play()
        fadeIn()
        delegate?.streamPlayerDidStartPlayback(self)
    }

    private func stopPlayback() {
        playerNode.stop()
        engine.stop()
        delegate?.streamPlayerDidStopPlayback(self)
    }

    func shoutcastStreamDidConnect(_ stream: ShoutcastStream) {
        do {
            try startPlayback()
        } catch {
            disconnect()
            return log.warning("Could not start audio playback: \(error)")
        }
    }

    func shoutcastStreamDidDisconnect(_ stream: ShoutcastStream) {
        disconnect()
        stopPlayback()
    }

    func shoutcastStream(_ stream: ShoutcastStream, gotNewTitle title: String) {
        delegate?.streamPlayer(self, didChangeSong: title)
    }

    func shoutcastStream(_ stream: ShoutcastStream, gotData data: Data) {
        adtsParser!.parse(data)
    }

    func adtsParserDidEncounterError(_ adtsParser: ADTSParser) {
        pause()
    }

    func adtsParser(_ adtsParser: ADTSParser, didParsePCMBuffer buffer: AVAudioPCMBuffer) {
        playerNode.scheduleBuffer(buffer)
    }

    private func fadeIn() {
        ramp(toVolume: 1, duration: 1)
    }

    private func fadeOut(completionHandler: @escaping () -> Void) {
        ramp(toVolume: 0, duration: 0.25, completionHandler: completionHandler)
    }

    private func ramp(toVolume: Double, duration: Double, completionHandler: (() -> Void)? = nil) {
        activeVolumeRamp = VolumeRamp(playerNode: playerNode, toVolume: toVolume, duration: duration, queue: delegateQueue) { [weak self] in
            self?.activeVolumeRamp = nil
            if let handler = completionHandler {
                handler()
            }
        }
    }
}

private class VolumeRamp {

    let playerNode: AVAudioPlayerNode
    var pendingSteps = 10
    let duration: Double
    let timeDelta: Double
    let volumeDelta: Double
    let queue: DispatchQueue
    let completionHandler: () -> Void

    init(playerNode: AVAudioPlayerNode, toVolume: Double, duration: Double, queue: DispatchQueue, completionHandler: @escaping () -> Void) {
        self.playerNode = playerNode
        self.duration = duration
        timeDelta = duration / Double(pendingSteps)
        volumeDelta = (toVolume - Double(playerNode.volume)) / Double(pendingSteps)
        self.queue = queue
        self.completionHandler = completionHandler

        ramp()
    }

    private func ramp() {
        if pendingSteps > 0 {
            let nextVolume = Double(playerNode.volume) + volumeDelta
            playerNode.volume = Float(clamp(nextVolume, between: 0, and: 1))

            pendingSteps -= 1

            queue.asyncAfter(deadline: DispatchTime.now() + timeDelta) { [weak self] in
                self?.ramp()
            }
        } else {
            completionHandler()
        }
    }

    private func clamp(_ x: Double, between a: Double, and b: Double) -> Double {
        let min_x = min(a, b)
        let max_x = max(a, b)
        if x < min_x {
            return min_x
        }
        if x > max_x {
            return max_x
        }
        return x
    }

}
