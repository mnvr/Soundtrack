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

    private func printInfo() {
        let ms = { Int($0 * 1000.0) }

        log.info("Querying \(audioSession):")
        log.info("\tCategory: \(audioSession.category) [Options = \(audioSession.categoryOptions)]")
        log.info("\tMode: \(audioSession.mode)")
        log.info("\tCurrent Route: \(audioSession.currentRoute)")
        log.info("\tOutput Channels: \(audioSession.outputNumberOfChannels) [max \(audioSession.maximumOutputNumberOfChannels)]")
        log.info("\tVolume: \(audioSession.outputVolume)")
        log.info("\tOutput Latency: \(ms(audioSession.outputLatency)) ms")
        log.info("\tI/O Buffer: \(ms(audioSession.ioBufferDuration)) ms")
        log.info("\tSample Rate: \(audioSession.sampleRate) hz")
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
        log.info("Configuring \(audioSession) for music playback")
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            return log.warning("Could not set audio session category: \(error)")
        }

        printInfo()

        log.info("Registering for receiving remote control events")
        UIApplication.shared.beginReceivingRemoteControlEvents()
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
