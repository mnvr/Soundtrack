//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import AVFoundation
import AudioToolbox

/// Convert AAC to PCM
///
/// An AAC SHOUTcast stream data consists of ADTS (Audio Data Transport Stream)
/// frames. Each such frame consists of a header followed by the AAC audio data.
///
/// The ADTS format is described in the MPEG-4 Audio standard (ISO/IEC 14496-3).

class ADTSParser {

    let pcmFormat: AVAudioFormat

    // The implementation of this class is based on the assumption that
    // `AudioFileStreamParseBytes` and `AudioConverterFillComplexBuffer`
    // call their callbacks synchronously.

    private var stream: AudioFileStreamID!
    private var converter: AudioConverterRef?
    private var framesPerPacket: UInt32 = 0
    private var pcmBuffers: [AVAudioPCMBuffer]? = []

    init(pcmFormat: AVAudioFormat) {
        precondition(pcmFormat.isStandard, "This class only supports conversion to PCM")

        self.pcmFormat = pcmFormat

        let context = Unmanaged.passUnretained(self).toOpaque()

        let propertyListener: AudioFileStream_PropertyListenerProc
        propertyListener  = { (context, streamID, propertyID, flags)  in
            let unsafeSelf = Unmanaged<ADTSParser>.fromOpaque(context).takeUnretainedValue()
            unsafeSelf.didParseProperty(id: propertyID)
        }

        let packetListener: AudioFileStream_PacketsProc
        packetListener = { (context, byteCount, packetCount, audioData, packetDescriptions) in
            let unsafeSelf = Unmanaged<ADTSParser>.fromOpaque(context).takeUnretainedValue()
            unsafeSelf.didParsePackets(byteCount, packetCount, audioData, packetDescriptions)
        }

        let filetypeHint = kAudioFileAAC_ADTSType

        var result: AudioFileStreamID?
        let status = AudioFileStreamOpen(context, propertyListener, packetListener, filetypeHint, &result)
        if status != 0 {
            fatalError("Could not open audio file stream: \(osStatusDescription(status))")
        }
        stream = result!
    }

    deinit {
        let status = AudioFileStreamClose(stream)
        if status != 0 {
            log.warning("Ignoring error when trying to close audio file stream: \(osStatusDescription(status))")
        }

        if let converter = converter {
            let status = AudioConverterDispose(converter)
            if status != 0 {
                log.warning("Ignoring error when trying to dispose audio converter: \(osStatusDescription(status))")
            }
        }
    }

    func parse(_ data: Data) -> [AVAudioPCMBuffer]? {
        guard pcmBuffers != nil else {
            return nil
        }

        data.enumerateBytes { (bytes, index, stop) in
            let status = AudioFileStreamParseBytes(stream, UInt32(bytes.count), bytes.baseAddress!, [])
            if status != 0 {
                log.warning("Audio file stream encountered an error when parsing the last \(bytes.count) bytes: \(osStatusDescription(status))")
                pcmBuffers = nil
                stop = true
            }
        }

        return pcmBuffers
    }

    private func didParseProperty(id propertyID: AudioFileStreamPropertyID) {
        guard pcmBuffers != nil else {
            return
        }

        switch propertyID {
        case kAudioFileStreamProperty_DataFormat:
            var asbd = AudioStreamBasicDescription()
            if getProperty(propertyID, &asbd) {
                log.info("Audio stream basic description: \(asbd)")
                createConverter(inputStreamDescription: &asbd)
            }

        default:
            log.debug("Parsed audio stream property \(fourCharCodeDescription(propertyID))")
        }
    }

    private func createConverter(inputStreamDescription: inout AudioStreamBasicDescription) {
        let status = AudioConverterNew(&inputStreamDescription, pcmFormat.streamDescription, &converter)
        if status != 0 {
            log.warning("Could not create audio converter to convert from \(inputStreamDescription) to \(pcmFormat): \(osStatusDescription(status))")
            pcmBuffers = nil
        } else {
            framesPerPacket = inputStreamDescription.mFramesPerPacket
        }
    }

    private func didParsePackets(_ byteCount: UInt32, _ packetCount: UInt32, _ audioData: UnsafeRawPointer, _ packetDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>) {
        guard pcmBuffers != nil else {
            return
        }

        guard converter != nil else {
            return
        }

        let audioBuffer = AudioBuffer(mNumberChannels: 1, mDataByteSize: byteCount, mData: UnsafeMutableRawPointer(mutating: audioData))
        let audioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)

        class Capture {
            let packetCount: UInt32
            let audioBufferList: AudioBufferList
            let packetDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?

            init(_ packetCount: UInt32, _ audioBufferList: AudioBufferList, _ packetDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>) {
                self.packetCount = packetCount
                self.audioBufferList = audioBufferList
                self.packetDescriptions = packetDescriptions
            }
        }

        let capture = Capture(packetCount, audioBufferList, packetDescriptions)
        let context = Unmanaged.passUnretained(capture).toOpaque()

        let inputDataProc: AudioConverterComplexInputDataProc
        inputDataProc = { (converter, packetCount, audioBufferList, packetDescriptions, context) -> OSStatus in
            let capture = Unmanaged<Capture>.fromOpaque(context!).takeUnretainedValue()
            packetCount.pointee = capture.packetCount
            audioBufferList.initialize(to: capture.audioBufferList, count: 1)
            packetDescriptions?.pointee = capture.packetDescriptions
            return 0
        }

        var frameCount = packetCount * framesPerPacket
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: frameCount)

        // AudioConverterFillComplexBuffer returns OSStatus -50 on iOS, without
        // even calling our inputDataProc. The very same code works on macOS.
        //
        // This was observed on the simulator that comes with Xcode 8, and
        // maybe this occurs in other conditions too.
        //
        // This workaround was taken from
        // https://forums.developer.apple.com/thread/65901

        do {
            let bufferList = outputBuffer.audioBufferList
            // Changes made to outputBuffer.mutableAudioBufferList do not persist.
            let mutableBufferList = UnsafeMutablePointer(mutating: bufferList)
            let outputBufferList = UnsafeMutableAudioBufferListPointer(mutableBufferList)
            let bytesPerFrame = outputBuffer.format.streamDescription.pointee.mBytesPerFrame
            let bytesPerChannel = frameCount * bytesPerFrame
            assert(!outputBuffer.format.isInterleaved)
            for i in 0..<outputBuffer.format.channelCount {
                outputBufferList[Int(i)].mDataByteSize = bytesPerChannel
            }
        }

        let status = AudioConverterFillComplexBuffer(converter!, inputDataProc, context, &frameCount, outputBuffer.mutableAudioBufferList, nil)
        if status != 0 {
            log.warning("AAC->PCM conversion failed: \(osStatusDescription(status))")
            pcmBuffers = nil
        } else {
            outputBuffer.frameLength = frameCount
            log.trace("Converted \(frameCount) frames from AAC to PCM")
            pcmBuffers!.append(outputBuffer)
        }
    }

    private func getProperty<T>(_ propertyID: AudioFileStreamPropertyID, _ result: inout T) -> Bool {
        var size = UInt32(MemoryLayout.size(ofValue: result))
        let status = AudioFileStreamGetProperty(stream, propertyID, &size, &result)
        if status != 0 {
            log.warning("Error when trying to fetch property \(fourCharCodeDescription(propertyID)) from the audio file stream: \(osStatusDescription(status))")
            pcmBuffers = nil
            return false
        }
        return true
    }

}

private func osStatusDescription(_ status: OSStatus) -> String {
    if status < 0 {
        return "OSStatus \(status)"
    }
    return "OSStatus \(fourCharCodeDescription(UInt32(status)))"
}

private func fourCharCodeDescription(_ code: UInt32) -> String {
    let chars = [(code & 0xff000000) >> 24,
                 (code & 0xff0000) >> 16,
                 (code & 0xff00) >> 8,
                 (code & 0xff)].map { UInt8($0) }
    if let fourCharCode = String(bytes: chars, encoding: .ascii) {
        return "'\(fourCharCode)' [\(code)]"
    } else {
        return "[\(code)]"
    }
}
