//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import AVFoundation

class AudioSession: NSObject {

    let audioSession: AVAudioSession = AVAudioSession.sharedInstance()

    var delegate: AudioSessionDelegate?

    var wasPlaying: Bool = false

    static let shared = AudioSession()

    override init() {
        super.init()
        observeAudioSessionNotifications()
    }

    func query(abridged: Bool = false) {
        logInfo("Querying \(audioSession)...")

        logInfo("Current audio session category: \(audioSession.category)")
        logInfo("Current audio session mode: \(audioSession.mode)")
        logInfo("Audio session category options: \(audioSession.categoryOptions)")

        if abridged {
            return
        }

        logInfo("Current route: \(audioSession.currentRoute)")

        logInfo("Available output data sources for the current route: \(audioSession.outputDataSources)")
        logInfo("Currently selected output data source: \(audioSession.outputDataSource)")

        logInfo("Maximum number of output channels available for the current route: \(audioSession.maximumOutputNumberOfChannels)")
        logInfo("Current number of output channels: \(audioSession.outputNumberOfChannels)")

        logInfo("System wide audio output volume set by the user: \(audioSession.outputVolume)")

        let ms = { Int($0 * 1000.0) }
        logInfo("Output latency (ms): \(ms(audioSession.outputLatency))")
        logInfo("I/O buffer duration (ms): \(ms(audioSession.ioBufferDuration))")

        logInfo("Sample rate (Hz): \(audioSession.sampleRate)")

        logInfo("Is another app currently playing (any) audio? \(audioSession.isOtherAudioPlaying)")
        logInfo("Is another app currently playing (primary) audio? \(audioSession.secondaryAudioShouldBeSilencedHint)")
    }

    private func observeAudioSessionNotifications() {
        logInfo("Attaching observers for audio session notifications")

        // The documentation states that these notifications should be
        // delivered on the main thread. However, it was observed when
        // running on a device (iPhone 4S, iOS 9.3) that they are instead
        // delivered on a thread named "AVAudioSession Notify Thread".

        observe(.AVAudioSessionInterruption, with: #selector(audioSessionInterruption(_:)))
        observe(.AVAudioSessionRouteChange, with: #selector(audioSessionRouteChange(_:)))
        observe(.AVAudioSessionMediaServicesWereLost, with: #selector(audioSessionMediaServicesWereLost(_:)))
        observe(.AVAudioSessionMediaServicesWereReset, with: #selector(audioSessionMediaServicesWereReset(_:)))
    }

    func configure() {
        query(abridged: true)

        logInfo("Configuring \(audioSession) for music playback")
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            logWarning("Could not set audio session category: \(error)")
            return
        }

        logInfo("Re-querying audio session post configuration...")
        query()
    }

    func activate() -> Bool {
        do {
            try audioSession.setActive(true)
        } catch {
            logWarning(error)
            return false
        }
        return true
    }

    func deactivate() -> Bool {
        do {
            try audioSession.setActive(false, with: .notifyOthersOnDeactivation)
        } catch {
            logWarning(error)
            return false
        }
        return true
    }

    // MARK: Audio Session Notifications

    func audioSessionInterruption(_ notification: Notification) {
        logInfo("Audio session interruption: \(notification)")

        guard let type: AVAudioSessionInterruptionType = notification.enumForKey( AVAudioSessionInterruptionTypeKey) else {
            return logWarning()
        }

        switch type {
        case .began:
            logInfo("Interruption began")
            if wasPlaying {
                delegate?.audioSessionWasInterrupted(self)
            }

        case .ended:
            logInfo("Interruption ended")

            guard let options: AVAudioSessionInterruptionOptions = notification.enumForKey(AVAudioSessionInterruptionOptionKey) else {
                break
            }

            logDebug("Interruption options: \(options)")
            if options.contains(.shouldResume) {
                logInfo("Interruption options mention that playback should resume")
                if wasPlaying {
                    delegate?.audioSessionPlaybackMayResume(self)
                }
            }
        }
    }

    func audioSessionRouteChange(_ notification: Notification) {
        logInfo("Audio route changed: \(notification)")

        if let reason: AVAudioSessionRouteChangeReason = notification.enumForKey(AVAudioSessionRouteChangeReasonKey) {

            logDebug("Route change reason: \(reason.rawValue)")

            if reason == .oldDeviceUnavailable {
                // e.g. headset was unplugged.
                logInfo("Route changed because old device became unavailable")

                if wasPlaying {
                    delegate?.audioSessionPlaybackShouldPause(self)
                }
            }
        }
    }

    func audioSessionMediaServicesWereLost(_ notification: Notification) {
        logInfo("Media services were lost: \(notification)")
        delegate?.audioSessionMediaServicesWereLost(self)
    }

    func audioSessionMediaServicesWereReset(_ notification: Notification) {
        logInfo("Media services were restarted: \(notification)")
        delegate?.audioSessionMediaServicesWereReset(self)
    }

}

protocol AudioSessionDelegate {

    func audioSessionWasInterrupted(_ audioSession: AudioSession)
    func audioSessionPlaybackShouldPause(_ audioSession: AudioSession)
    func audioSessionPlaybackMayResume(_ audioSession: AudioSession)

    func audioSessionMediaServicesWereLost(_ audioSession: AudioSession)
    func audioSessionMediaServicesWereReset(_ audioSession: AudioSession)

}
