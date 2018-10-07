//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Cocoa

class ViewController: NSViewController, NSUserInterfaceValidations, AudioControllerDelegate, StreamPlayerDelegate {
    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var titleStackView: NSStackView!
    @IBOutlet weak var songTextField: NSTextField!
    @IBOutlet weak var artistTextField: NSTextField!
    @IBOutlet weak var clickGestureRecognizer: NSClickGestureRecognizer!
    var statusItem: NSStatusItem?

    let configuration = Configuration.shared
    private var audioController: AudioController?
    private var isPlaying: Bool = false
    private var currentPlaybackAttempt: Int = 0
    private var lastTitle: String?
    private var togglePlaybackMenuItemTitle: String?
    private var togglePlaybackMenuItemIsEnabled: Bool?

    override func viewDidLoad() {
        super.viewDidLoad()

        observeUserDefaultsController()
        updateStatusBarItem()
        updateDockIcon()

        indicateUnavailability()

        tryMakeAudioController()
    }

    deinit {
        unobserveUserDefaultsController()
    }

    func tryMakeAudioController() {
        if let url = configuration.shoutcastURL {
            audioController = makePlaybackController(url: url)
        }
    }

    private func makePlaybackController(url: URL) -> AudioController {
        let makeSession = { queue in
            return AudioSessionMacOS(queue: queue)
        }

        return AudioController(url: url, delegate: self, delegateQueue: DispatchQueue.main, makeSession: makeSession)
    }

    @IBAction func play(_ sender: NSButton) {
        log.info("User pressed play")
        prepareForPlaybackStart()
        audioController?.playPause()
    }

    @IBAction func pause(_ sender: NSGestureRecognizer) {
        log.info("User clicked inside the window")
        prepareForPlaybackStop()
        audioController?.playPause()
    }

    @IBAction func togglePlayback(_ sender: NSMenuItem) {
        guard togglePlaybackMenuItemIsEnabled == true else {
            log.warning("Ignoring menu toggle because menu is currently intended to be disabled")
            return
        }

        log.info("User invoked menu toggle")
        toggle()
    }

    private func toggle() {
        isPlaying ? prepareForPlaybackStop() : prepareForPlaybackStart()
        audioController?.playPause()
    }

    private func indicateUnavailability() {
        isPlaying = false

        playButton.isEnabled = false
        playButton.isHidden = false

        progressIndicator.stopAnimation(self)

        titleStackView.isHidden = true

        clickGestureRecognizer.isEnabled = false

        togglePlaybackMenuItemTitle = menuTitlePlay()
        togglePlaybackMenuItemIsEnabled = false

        unhighlightStatusButton()
        clearStatusButtonTooltip()
    }

    func audioControllerDidBecomeAvailable(_ audioController: AudioController) {
        playButton.isEnabled = true
        togglePlaybackMenuItemIsEnabled = true
    }

    func audioControllerDidBecomeUnavailable(_ audioController: AudioController) {
        indicateUnavailability()
    }

    private func prepareForPlaybackStart() {
        playButton.isEnabled = false

        togglePlaybackMenuItemIsEnabled = false
    }

    func audioControllerWillStartPlayback(_ audioController: AudioController) {
        prepareForPlaybackStart()

        currentPlaybackAttempt += 1
        let playbackAttempt = currentPlaybackAttempt

        fadeOut(playButton) { [weak self] in
            self?.maybeShowProgressIndicatorForPlaybackAttempt(playbackAttempt)
        }
    }

    private func maybeShowProgressIndicatorForPlaybackAttempt(_ playbackAttempt: Int) {
        if !isPlaying {
            if playbackAttempt == currentPlaybackAttempt {
                progressIndicator.startAnimation(self)
            }
        }
    }

    private func maybeCancelProgressIndicator() {
        currentPlaybackAttempt += 1

        progressIndicator.stopAnimation(self)
    }

    func streamPlayerDidStartPlayback(_ streamPlayer: StreamPlayer) {
        isPlaying = true

        maybeCancelProgressIndicator()

        clickGestureRecognizer.isEnabled = true

        togglePlaybackMenuItemTitle = menuTitlePause()
        togglePlaybackMenuItemIsEnabled = true

        highlightStatusButton()
    }

    private func prepareForPlaybackStop() {
        clickGestureRecognizer.isEnabled = false

        togglePlaybackMenuItemIsEnabled = false
    }

    func audioControllerWillStopPlayback(_ audioController: AudioController) {
        prepareForPlaybackStop()

        maybeCancelProgressIndicator()

        isPlaying = false

        fadeOut(titleStackView)

        clearStatusButtonTooltip()
    }

    func streamPlayerDidStopPlayback(_ streamPlayer: StreamPlayer) {
        playButton.isEnabled = true
        fadeIn(playButton)

        togglePlaybackMenuItemTitle = menuTitlePlay()
        togglePlaybackMenuItemIsEnabled = true

        unhighlightStatusButton()
    }

    func streamPlayer(_ streamPlayer: StreamPlayer, didChangeSong title: String) {
        let titleComponents = TitleComponents(title)

        setTitleComponents(titleComponents)
        setStatusButtonTooltip(title)
        maybeShowNotification(titleComponents)
    }

    private func setTitleComponents(_ titleComponents: TitleComponents) {
        let maybeFadeInTitle = { [weak self] in
            if !titleComponents.title.isEmpty {
                self?.setTitleComponents2(titleComponents)
            }
        }

        if titleStackView.isHidden {
            maybeFadeInTitle()
        } else {
            fadeOut(titleStackView) {
                maybeFadeInTitle()
            }
        }
    }

    private func setTitleComponents2(_ titleComponents: TitleComponents) {
        songTextField.stringValue = titleComponents.song
        artistTextField.stringValue = titleComponents.artist

        fadeIn(titleStackView)
    }

    private func fadeOut(_ view: NSView, duration: TimeInterval = 2, then: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            view.animator().isHidden = true
        }, completionHandler: then)
    }

    private func fadeIn(_ view: NSView, duration: TimeInterval = 2, then: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            view.animator().isHidden = false
        }, completionHandler: then)
    }

    private func menuTitlePlay() -> String {
        return NSLocalizedString("Play", comment: "Menu Item - Music > Play")
    }

    private func menuTitlePause() -> String {
        return NSLocalizedString("Pause", comment: "Menu Item - Music > Pause")
    }

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if let menuItem = item as? NSMenuItem, menuItem.action == #selector(togglePlayback(_:)) {
            if let title = togglePlaybackMenuItemTitle {
                menuItem.title = title
            }
            return togglePlaybackMenuItemIsEnabled ?? false
        }

        return true
    }

    private func makeStatusButtonItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.image = #imageLiteral(resourceName: "StatusBarButton")
        item.action = #selector(statusBarEvent)
        item.target = self
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        return item
    }

    @objc private func statusBarEvent(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent {
            if event.modifierFlags.contains(.control) || event.type == .rightMouseUp {
                configuration.hideDockIcon = false
                view.window?.makeKeyAndOrderFront(self)
                view.window?.makeMain()
            } else {
                if togglePlaybackMenuItemIsEnabled == true {
                    toggle()
                }
            }
        }
    }

    private func removeStatusBarItem() {
        if let item = statusItem {
            item.statusBar?.removeStatusItem(item)
        }
        statusItem = nil
    }

    private func setStatusButtonTooltip(_ title: String) {
        statusItem?.toolTip = title
        lastTitle = title
    }

    private func clearStatusButtonTooltip() {
        setStatusButtonTooltip("")
    }

    private func highlightStatusButton() {
        statusItem?.button!.appearsDisabled = false
    }

    private func unhighlightStatusButton() {
        statusItem?.button!.appearsDisabled = true
    }

    private func updateStatusBarItem() {
        if configuration.hideStatusBarIcon {
            if statusItem != nil {
                removeStatusBarItem()
            }
        } else {
            if statusItem == nil {
                statusItem = makeStatusButtonItem()
                gleanStatusItemState()
            }
        }
    }

    private func gleanStatusItemState() {
        if titleStackView.isHidden {
            unhighlightStatusButton()
        } else {
            highlightStatusButton()
        }
        statusItem?.toolTip = lastTitle
    }

    private func updateDockIcon() {
        if configuration.hideDockIcon {
            NSApp?.setActivationPolicy(.accessory)
        } else {
            NSApp?.setActivationPolicy(.regular)
        }
    }

    private var userDefaultsController = NSUserDefaultsController.shared
    // Apparently, cannot use Swift 4 KVO with NSUserDefaultsController,
    // so do it the old way.
    private var observationContext = 0
    private let hideStatusBarIconKVOPath = "values.hideStatusBarIcon"
    private let hideDockIconKVOPath = "values.hideDockIcon"

    private func observeUserDefaultsController() {
        userDefaultsController.addObserver(self, forKeyPath: hideStatusBarIconKVOPath, options: [], context: &observationContext)
        userDefaultsController.addObserver(self, forKeyPath: hideDockIconKVOPath, options: [], context: &observationContext)
    }

    private func unobserveUserDefaultsController() {
        userDefaultsController.removeObserver(self, forKeyPath: hideStatusBarIconKVOPath, context: &observationContext)
        userDefaultsController.removeObserver(self, forKeyPath: hideDockIconKVOPath, context: &observationContext)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &observationContext {
            if keyPath == hideStatusBarIconKVOPath {
                updateStatusBarItem()
            } else if keyPath == hideDockIconKVOPath {
                updateDockIcon()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    private func maybeShowNotification(_ titleComponents: TitleComponents) {
        if configuration.hideNotifications {
            return
        }

        let notification = NSUserNotification()
        notification.title = titleComponents.song
        notification.subtitle = titleComponents.artist
        NSUserNotificationCenter.default.deliver(notification)
    }

    @objc func paste(_ sender: Any) {
        let pasteboard = NSPasteboard.general
        if let urlString = pasteboard.string(forType: .string),
            let url = URL(string: urlString) {
            NSLog("URL was pasted: \(url)")
            configuration.updateShoutcastURL(playlistURL: url) { [weak self] _ in
                self?.tryMakeAudioController()
            }
        }
    }
}
