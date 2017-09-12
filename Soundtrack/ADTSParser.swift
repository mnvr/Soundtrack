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

    weak var delegate: ADTSParserDelegate?

    private var stream: AudioFileStreamID!
    private var converter: AudioConverterRef?

    private var didEncounterError: Bool = false

    private var framesPerPacket: Int = 0

    /// Create a new ADTS parser.
    ///
    /// - Parameter pcmFormat: Format of the converted buffers provided
    ///   to the delegate.
    ///
    /// - Precondition: `pcmFormat` should be a standard format.

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

    /// The delegate methods are called synchronously during
    /// the execution of this method.

    func parse(_ data: Data) {
        guard !didEncounterError else {
            return
        }

        data.enumerateBytes { (bytes, index, stop) in
            let status = AudioFileStreamParseBytes(stream, UInt32(bytes.count), bytes.baseAddress!, [])
            if status != 0 {
                log.warning("Audio file stream encountered an error when parsing the last \(bytes.count) bytes: \(osStatusDescription(status))")
                errorOut()
                stop = true
            }
        }
    }

    private func errorOut() {
        if !didEncounterError {
            didEncounterError = true
            delegate?.adtsParserDidEncounterError(self)
        }
    }

    private func didParseProperty(id propertyID: AudioFileStreamPropertyID) {
        guard !didEncounterError else {
            return
        }

        switch propertyID {
        case kAudioFileStreamProperty_DataFormat:
            var asbd = AudioStreamBasicDescription()
            if !getProperty(propertyID, &asbd) {
                return errorOut()
            }
            log.info("Audio stream basic description: \(asbd)")
            if !createConverter(inputStreamDescription: &asbd) {
                return errorOut()
            }

        default:
            log.trace("Parsed audio stream property \(fourCharCodeDescription(propertyID))")
        }
    }

    private func getProperty<T>(_ propertyID: AudioFileStreamPropertyID, _ result: inout T) -> Bool {
        var size = UInt32(MemoryLayout.size(ofValue: result))
        let status = AudioFileStreamGetProperty(stream, propertyID, &size, &result)
        if status != 0 {
            log.warning("Error when trying to fetch property \(fourCharCodeDescription(propertyID)) from the audio file stream: \(osStatusDescription(status))")
            return false
        }
        return true
    }

    private func createConverter(inputStreamDescription: inout AudioStreamBasicDescription) -> Bool {
        guard converter == nil else {
            log.warning("Trying to create a new converter for \(inputStreamDescription) when there is an already existing converter: \(converter)")
            return false
        }

        let status = AudioConverterNew(&inputStreamDescription, pcmFormat.streamDescription, &converter)
        guard status == 0 else {
            log.warning("Could not create audio converter to convert from \(inputStreamDescription) to \(pcmFormat): \(osStatusDescription(status))")
            return false
        }

        framesPerPacket = Int(inputStreamDescription.mFramesPerPacket)
        log.debug("Each input packet contains \(framesPerPacket) frames of audio")

        return true
    }

    private func didParsePackets(_ byteCountUInt32: UInt32, _ packetCountUInt32: UInt32, _ audioDataPointer: UnsafeRawPointer, _ packetDescriptionsPointer: UnsafeMutablePointer<AudioStreamPacketDescription>) {
        guard !didEncounterError else {
            return
        }

        let byteCount = Int(byteCountUInt32)
        let packetCount = Int(packetCountUInt32)

        let audioDataBytesPointer = UnsafeMutableRawPointer(mutating: audioDataPointer).assumingMemoryBound(to: UInt8.self)

        let bytes = UnsafeMutableBufferPointer<UInt8>(start: audioDataBytesPointer, count: byteCount)
        let packetDescriptions = UnsafeMutableBufferPointer<AudioStreamPacketDescription>(start: packetDescriptionsPointer, count: packetCount)

        guard let pcmBuffer = convert(bytes: bytes, packetDescriptions: packetDescriptions) else {
            return errorOut()
        }

        delegate?.adtsParser(self, didParsePCMBuffer: pcmBuffer)
    }

    private func convert(bytes: UnsafeMutableBufferPointer<UInt8>, packetDescriptions: UnsafeMutableBufferPointer<AudioStreamPacketDescription>) -> AVAudioPCMBuffer? {

        guard let converter = converter else {
            log.warning("The audio stream is trying to convert audio packets without informing us about the audio format")
            return nil
        }

        class InputProcContext {
            let packetCount: UInt32
            let audioBufferList: AudioBufferList
            let packetDescriptions: UnsafeMutableBufferPointer<AudioStreamPacketDescription>

            private var audioBuffer: AudioBuffer

            init(bytes: UnsafeMutableBufferPointer<UInt8>, packetDescriptions: UnsafeMutableBufferPointer<AudioStreamPacketDescription>) {

                packetCount = UInt32(packetDescriptions.count)

                audioBuffer = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(bytes.count), mData: bytes.baseAddress)
                audioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)

                self.packetDescriptions = packetDescriptions
            }
        }

        let context = InputProcContext(bytes: bytes, packetDescriptions: packetDescriptions)
        let contextPointer = Unmanaged.passUnretained(context).toOpaque()

        let inputDataProc: AudioConverterComplexInputDataProc
        inputDataProc = { (converter, ioPacketCount, audioBufferList, optionalPacketDescriptions, contextPointer) -> OSStatus in
            let context = Unmanaged<InputProcContext>.fromOpaque(contextPointer!).takeUnretainedValue()
            ioPacketCount.pointee = context.packetCount
            audioBufferList.initialize(to: context.audioBufferList)
            optionalPacketDescriptions?.pointee = context.packetDescriptions.baseAddress
            return 0
        }

        var frameCount = AVAudioFrameCount(packetDescriptions.count * framesPerPacket)
        var outputBuffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: frameCount)

        let outputBufferList = fixOutputBufferFrameLength(outputBuffer: &outputBuffer)

        let status = AudioConverterFillComplexBuffer(converter, inputDataProc, contextPointer, &frameCount, outputBufferList, nil)
        if status != 0 {
            log.warning("AAC->PCM conversion failed: \(osStatusDescription(status))")
            return nil
        }

        // AudioConverterFillComplexBuffer does not know about the
        // AVAudioPCMBuffer, and we must update its state ourselves.

        outputBuffer.frameLength = outputBuffer.frameCapacity

        log.trace("Converted \(frameCount) frames from AAC to PCM")

        return outputBuffer

    }

    private func fixOutputBufferFrameLength(outputBuffer: inout AVAudioPCMBuffer) -> UnsafeMutablePointer<AudioBufferList> {

        // AudioConverterFillComplexBuffer returns OSStatus -50 on iOS, without
        // even calling our inputDataProc. The very same code works on macOS.
        //
        // This was observed on the simulator that comes with Xcode 8, and
        // maybe this occurs in other conditions too.
        //
        // This workaround was taken from
        // https://forums.developer.apple.com/thread/65901

        let frameCount = outputBuffer.frameCapacity

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

        return mutableBufferList

    }

}

protocol ADTSParserDelegate: class {

    /// The parser reaches an invalid state at this point. The client should
    /// let go of this instance and create a new one.

    func adtsParserDidEncounterError(_ adtsParser: ADTSParser)

    func adtsParser(_ adtsParser: ADTSParser, didParsePCMBuffer buffer: AVAudioPCMBuffer)

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
    if let fourCharCode = String(bytes: chars, encoding: .ascii), !fourCharCode.isEmpty {
        return "'\(fourCharCode)' [\(code)]"
    } else {
        return "[\(code)]"
    }
}
