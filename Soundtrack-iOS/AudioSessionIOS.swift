//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit
import AVFoundation

class AudioSessionIOS: NSObject, AudioSession {

    let queue: DispatchQueue

    weak var delegate: AudioSessionDelegate?

    private let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    static var count = 0

    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    private var wasPlaying: Bool = false

    init(queue: DispatchQueue) {
        if AudioSessionIOS.count != 0 {
            fatalError("We can only have one instance of Audio Session on iOS at a time, because they share the underlying singleton instance of AVAudioSession")
        }
        AudioSessionIOS.count += 1

        self.queue = queue

        super.init()
        
        observeAudioSessionNotifications()
        configure()
    }

    deinit {
        AudioSessionIOS.count -= 1
    }

    private func observeAudioSessionNotifications() {
        // The documentation states that these notifications should be
        // delivered on the main thread. However, it was observed when
        // running on a device (iPhone 4S, iOS 9.3) that they are instead
        // delivered on a thread named "AVAudioSession Notify Thread".

        observeOnQueue(.AVAudioSessionInterruption, with: #selector(audioSessionInterruption(_:)))
        observeOnQueue(.AVAudioSessionRouteChange, with: #selector(audioSessionRouteChange(_:)))
        observeOnQueue(.AVAudioSessionMediaServicesWereLost, with: #selector(audioSessionMediaServicesWereLost(_:)))
        observeOnQueue(.AVAudioSessionMediaServicesWereReset, with: #selector(audioSessionMediaServicesWereReset(_:)))
    }


    private func configure() {
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            return log.warning("Could not set audio session category: \(error)")
        }

        logAudioSessionState()
    }

    private func logAudioSessionState() {
        log.info("Querying \(audioSession):")

        let ms = { Int($0 * 1000.0) }

        log.info("\tCategory: \(audioSession.category) [Options = \(audioSession.categoryOptions)]")
        log.info("\tMode: \(audioSession.mode)")
        log.info("\tCurrent Route: \(audioSession.currentRoute)")
        log.info("\tOutput Channels: \(audioSession.outputNumberOfChannels) [max \(audioSession.maximumOutputNumberOfChannels)]")
        log.info("\tVolume: \(audioSession.outputVolume)")
        log.info("\tOutput Latency: \(ms(audioSession.outputLatency)) ms")
        log.info("\tI/O Buffer: \(ms(audioSession.ioBufferDuration)) ms")
        log.info("\tSample Rate: \(audioSession.sampleRate) hz")
    }

    func activate() -> Bool {
        beginBackgroundTask()

        do {
            try audioSession.setActive(true)
        } catch {
            endBackgroundTask()
            log.warning("Could not activate audio session: \(error)")
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
            log.warning("Could not deactivate audio session: \(error)")
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
        log.debug("Did begin background task with identifier \(backgroundTaskIdentifier)")
    }

    private func endBackgroundTask() {
        guard let backgroundTaskIdentifier = backgroundTaskIdentifier else {
            return log.warning()
        }

        log.debug("Will end background task with identifier \(backgroundTaskIdentifier)")
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)

        self.backgroundTaskIdentifier = nil
    }
    
    // MARK: Audio Session Notifications

    func audioSessionInterruption(_ notification: Notification) {
        log.debug("Audio session interruption: \(notification)")

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
        log.debug("Audio route changed: \(notification)")

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


    // MARK: Forwarding Notifications

    private var selectorForNotificationName = Dictionary<Notification.Name, Selector>()

    private func observeOnQueue(_ name: Notification.Name, with selector: Selector) {
        if selectorForNotificationName.isEmpty {
            let forwarder = #selector(_observeForwarder(_:))
            NotificationCenter.default.addObserver(self, selector: forwarder, name: name, object: nil)
        }

        selectorForNotificationName[name] = selector
    }

    @objc private func _observeForwarder(_ notification: Notification) {
        if let selector = selectorForNotificationName[notification.name] {
            queue.async { [weak self] in
                _ = self?.perform(selector, with: notification)
            }
        }
    }
}
