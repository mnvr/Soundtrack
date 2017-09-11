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
    let bufferDuration: TimeInterval

    weak var delegate: ADTSParserDelegate?

    private var stream: AudioFileStreamID!
    private var converter: AudioConverterRef?

    private var didEncounterError: Bool = false

    private var framesPerPacket: Int = 0

    private var maximumPendingBytesCount: Int = 0
    private var maximumPendingPacketsCount: Int = 0

    private var pendingBytes: UnsafeMutablePointer<UInt8>!
    private var pendingAudioBuffers: UnsafeMutablePointer<AudioBuffer>!
    private var pendingPacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>!

    private var pendingBytesCount: Int = 0
    private var pendingAudioBuffersCount = 0
    private var pendingPacketsCount: Int = 0

    /// Create a new ADTS parser.
    ///
    /// - Parameter pcmFormat: Output format of the buffers vended by the
    ///   delegate methods. This must be a standard format. The parser uses
    ///   it to determine the other varying parameters like sample rate.
    ///
    /// - Precondition: `pcmFormat` should be a standard format.
    ///
    /// - Parameter bufferDuration: The parser will buffer input until it has
    ///   sufficient data to produce an output PCM buffer that is at least
    ///   `bufferDuration` long. Note that this is a best effort contract
    ///   and might be violated (i.e. smaller buffers may be emitted in
    ///   certain scenarios).

    init(pcmFormat: AVAudioFormat, bufferDuration: TimeInterval = 1.0) {
        precondition(pcmFormat.isStandard, "This class only supports conversion to PCM")

        self.pcmFormat = pcmFormat
        self.bufferDuration = bufferDuration

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

        deallocateBuffers()
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
            log.debug("Parsed audio stream property \(fourCharCodeDescription(propertyID))")
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
        log.info("Each input packet contains \(framesPerPacket) frames of audio")

        let maximumPendingFramesCount = Int(bufferDuration * pcmFormat.sampleRate)
        maximumPendingPacketsCount = maximumPendingFramesCount / framesPerPacket
        maximumPendingBytesCount = maximumPendingPacketsCount * maximumInputPacketBytesCount()

        log.info("Buffer size: \(maximumPendingPacketsCount) packets / \(maximumPendingFramesCount) frames / \(maximumPendingBytesCount) bytes")

        allocateBuffers()

        return true
    }

    private func maximumInputPacketBytesCount() -> Int {
        let maximumPacketBytesCount: Int
        do {
            var maximumPacketSize: UInt32 = 0
            if !getProperty(kAudioFileStreamProperty_MaximumPacketSize, &maximumPacketSize) || maximumPacketSize == 0 {
                let pcmBytesPerFrame = pcmFormat.streamDescription.pointee.mBytesPerFrame
                maximumPacketSize = UInt32(framesPerPacket) * pcmBytesPerFrame
                log.info("Cannot determine the maximum size of an input packet; falling back to using the maximum size of an equivalent number of PCM frames")
            }
            maximumPacketBytesCount = Int(maximumPacketSize)
        }
        log.info("The maximum size of an input packet is expected to be \(maximumPacketBytesCount) bytes")
        return maximumPacketBytesCount
    }

    private func allocateBuffers() {
        pendingBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: maximumPendingBytesCount)
        pendingAudioBuffers = UnsafeMutablePointer<AudioBuffer>.allocate(capacity: maximumPendingPacketsCount)
        pendingPacketDescriptions = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: maximumPendingPacketsCount)
    }

    private func deallocateBuffers() {
        if let bytes = pendingBytes {
            bytes.deallocate(capacity: maximumPendingBytesCount)
            pendingBytes = nil
        }
        if let audioBuffers = pendingAudioBuffers {
            audioBuffers.deallocate(capacity: maximumPendingPacketsCount)
            pendingAudioBuffers = nil
        }
        if let packetDescriptions = pendingPacketDescriptions {
            packetDescriptions.deallocate(capacity: maximumPendingPacketsCount)
            pendingPacketDescriptions = nil
        }
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

        if !didParse(bytes: bytes, packetDescriptions: packetDescriptions) {
            errorOut()
        }
    }

    // The input arguments will remain valid only for the duration of this
    // function, so we need to copy them if they're going to be needed later.

    private func didParse(bytes: UnsafeMutableBufferPointer<UInt8>, packetDescriptions: UnsafeMutableBufferPointer<AudioStreamPacketDescription>) -> Bool {

        return convert(bytes: bytes, packetDescriptions: packetDescriptions)
/*
        if pendingBytesCount + bytes.count > maximumPendingBytesCount ||
            pendingPacketsCount + packetDescriptions.count > maximumPendingPacketsCount {
            if !convertPending() {
                return false
            }
        }

        if bytes.count > maximumPendingBytesCount ||
            packetDescriptions.count > maximumPendingPacketsCount {
            return convert(bytes: bytes, packetDescriptions: packetDescriptions)
        }

        buffer(bytes: bytes, packetDescriptions: packetDescriptions)
        return true */

    }

    private func convertPending() -> Bool {
        if pendingPacketsCount == 0 {
            return true
        }
        
        let audioBuffers = UnsafeMutableBufferPointer<AudioBuffer>(start: pendingAudioBuffers, count: pendingAudioBuffersCount)
        let packetDescriptions = UnsafeMutableBufferPointer<AudioStreamPacketDescription>(start: pendingPacketDescriptions, count: pendingPacketsCount)

        let pcmBuffer = convert(audioBuffers: audioBuffers, packetDescriptions: packetDescriptions)

        pendingBytesCount = 0
        pendingAudioBuffersCount = 0
        pendingPacketsCount = 0

        if pcmBuffer == nil {
            return false
        }

        delegate?.adtsParser(self, didParsePCMBuffer: pcmBuffer!)
        return true
    }

    private func convert(bytes: UnsafeMutableBufferPointer<UInt8>, packetDescriptions: UnsafeMutableBufferPointer<AudioStreamPacketDescription>) -> Bool {

        var audioBuffer = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(bytes.count), mData: bytes.baseAddress)
        let audioBuffers = UnsafeMutableBufferPointer(start: &audioBuffer, count: 1)

        guard let pcmBuffer = convert(audioBuffers: audioBuffers, packetDescriptions: packetDescriptions) else {
            return false
        }

        delegate?.adtsParser(self, didParsePCMBuffer: pcmBuffer)
        return true
    }


    private func buffer(bytes: UnsafeMutableBufferPointer<UInt8>, packetDescriptions: UnsafeMutableBufferPointer<AudioStreamPacketDescription>) {

        assert(pendingBytesCount + bytes.count <= maximumPendingBytesCount)
        assert(pendingAudioBuffersCount + 1 <= maximumPendingPacketsCount)
        assert(pendingPacketsCount + packetDescriptions.count <= maximumPendingPacketsCount)

        let nextPendingBytes = pendingBytes.advanced(by: pendingBytesCount)
        let nextPendingAudioBuffers = pendingAudioBuffers.advanced(by: pendingAudioBuffersCount)
        let nextPendingPacketDescriptions = pendingPacketDescriptions.advanced(by: pendingPacketsCount)

        var audioBuffer = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(bytes.count), mData: nextPendingBytes)

        nextPendingBytes.initialize(from: bytes.baseAddress!, count: bytes.count)
        nextPendingAudioBuffers.initialize(from: &audioBuffer, count: 1)
        nextPendingPacketDescriptions.initialize(from: packetDescriptions.baseAddress!, count: packetDescriptions.count)

        pendingBytesCount += bytes.count
        pendingAudioBuffersCount += 1
        pendingPacketsCount += packetDescriptions.count

    }


    private func convert(audioBuffers: UnsafeMutableBufferPointer<AudioBuffer>, packetDescriptions: UnsafeMutableBufferPointer<AudioStreamPacketDescription>) -> AVAudioPCMBuffer? {

        guard let converter = converter else {
            log.warning("The audio stream is trying to convert audio packets without informing us about the audio format")
            return nil
        }

        class InputProcContext {
            let packetCount: UInt32
            let audioBufferList: AudioBufferList
            let packetDescriptions: UnsafeMutableBufferPointer<AudioStreamPacketDescription>

            init(audioBuffers: UnsafeMutableBufferPointer<AudioBuffer>, packetDescriptions: UnsafeMutableBufferPointer<AudioStreamPacketDescription>) {
                packetCount = UInt32(packetDescriptions.count)
                audioBufferList = AudioBufferList(mNumberBuffers: UInt32(audioBuffers.count), mBuffers: audioBuffers[0])
                self.packetDescriptions = packetDescriptions
            }
        }

        let context = InputProcContext(audioBuffers: audioBuffers, packetDescriptions: packetDescriptions)
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

        // TODO FIXME is this required?
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
