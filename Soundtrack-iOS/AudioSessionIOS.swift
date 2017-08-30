//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit
import AVFoundation

class AudioSessionIOS: NSObject, AudioSession {

    static let shared = AudioSessionIOS()

    let audioSession: AVAudioSession = AVAudioSession.sharedInstance()

    weak var delegate: AudioSessionDelegate?

    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    private var wasPlaying: Bool = false

    override init() {
        super.init()
        
        observeAudioSessionNotifications()
    }

    private func query(abridged: Bool = false) {
        log.info("Querying \(audioSession)...")

        log.info("Current audio session category: \(audioSession.category)")
        log.info("Current audio session mode: \(audioSession.mode)")
        log.info("Audio session category options: \(audioSession.categoryOptions)")

        if abridged {
            return
        }

        log.info("Current route: \(audioSession.currentRoute)")

        log.info("Available output data sources for the current route: \(audioSession.outputDataSources)")
        log.info("Currently selected output data source: \(audioSession.outputDataSource)")

        log.info("Maximum number of output channels available for the current route: \(audioSession.maximumOutputNumberOfChannels)")
        log.info("Current number of output channels: \(audioSession.outputNumberOfChannels)")

        log.info("System wide audio output volume set by the user: \(audioSession.outputVolume)")

        let ms = { Int($0 * 1000.0) }
        log.info("Output latency (ms): \(ms(audioSession.outputLatency))")
        log.info("I/O buffer duration (ms): \(ms(audioSession.ioBufferDuration))")

        log.info("Sample rate (Hz): \(audioSession.sampleRate)")

        log.info("Is another app currently playing (any) audio? \(audioSession.isOtherAudioPlaying)")
        log.info("Is another app currently playing (primary) audio? \(audioSession.secondaryAudioShouldBeSilencedHint)")
    }

    private func observeAudioSessionNotifications() {
        log.info("Attaching observers for audio session notifications")

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

        log.info("Configuring \(audioSession) for music playback")
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            return log.warning("Could not set audio session category: \(error)")
        }

        log.info("Registering for receiving remote control events")
        UIApplication.shared.beginReceivingRemoteControlEvents()

        log.info("Re-querying audio session post configuration...")
        query()
    }

    func activate() -> Bool {
        beginBackgroundTask()

        do {
            try audioSession.setActive(true)
        } catch {
            endBackgroundTask()
            log.warning(error)
            return false
        }

        wasPlaying = true

        return true
    }

    func deactivate() -> Bool {
        wasPlaying = false

        defer {
            endBackgroundTask()
        }

        do {
            try audioSession.setActive(false, with: .notifyOthersOnDeactivation)
        } catch {
            log.warning(error)
            return false
        }

        return true
    }

    // MARK: Background Task

    private func beginBackgroundTask() {
        if backgroundTaskIdentifier != nil {
            return log.warning()
        }
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            log.warning("We were asked to relinquish our background task before playback ended")
        })
        log.info("Did begin background task with identifier \(backgroundTaskIdentifier)")
    }

    private func endBackgroundTask() {
        guard let backgroundTaskIdentifier = backgroundTaskIdentifier else {
            return log.warning()
        }

        log.info("Will end background task with identifier \(backgroundTaskIdentifier)")
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)

        self.backgroundTaskIdentifier = nil
    }
    
    // MARK: Audio Session Notifications

    func audioSessionInterruption(_ notification: Notification) {
        log.info("Audio session interruption: \(notification)")

        guard let type: AVAudioSessionInterruptionType = notification.enumForKey( AVAudioSessionInterruptionTypeKey) else {
            return log.warning()
        }

        switch type {
        case .began:
            log.info("Interruption began")
            if wasPlaying {
                endBackgroundTask()
                delegate?.audioSessionWasInterrupted(self)
            }

        case .ended:
            log.info("Interruption ended")

            guard let options: AVAudioSessionInterruptionOptions = notification.enumForKey(AVAudioSessionInterruptionOptionKey) else {
                break
            }

            log.debug("Interruption options: \(options)")
            if options.contains(.shouldResume) {
                log.info("Interruption options mention that playback should resume")
                if wasPlaying {
                    delegate?.audioSessionPlaybackShouldResume(self)
                }
            }
        }
    }

    func audioSessionRouteChange(_ notification: Notification) {
        log.info("Audio route changed: \(notification)")

        if let reason: AVAudioSessionRouteChangeReason = notification.enumForKey(AVAudioSessionRouteChangeReasonKey) {

            log.debug("Route change reason: \(reason.rawValue)")

            if reason == .oldDeviceUnavailable {
                // e.g. headset was unplugged.
                log.info("Route changed because old device became unavailable")

                if wasPlaying {
                    delegate?.audioSessionPlaybackShouldPause(self)
                }
            }
        }
    }

    func audioSessionMediaServicesWereLost(_ notification: Notification) {
        log.info("Media services were lost: \(notification)")
        wasPlaying = false
        endBackgroundTask()
        delegate?.audioSessionMediaServicesWereLost(self)
    }

    func audioSessionMediaServicesWereReset(_ notification: Notification) {
        log.info("Media services were restarted: \(notification)")
        delegate?.audioSessionMediaServicesWereReset(self)
    }

}
