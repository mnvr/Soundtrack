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
    @IBOutlet weak var togglePlaybackMenuItem: NSMenuItem!

    var statusItem: NSStatusItem?

    private var audioController: AudioController!

    private var isPlaying: Bool = false
    private var currentPlaybackAttempt: Int = 0
    private var lastTitle: String?

    private var togglePlaybackMenuItemTitle: String?
    private var togglePlaybackMenuItemIsEnabled: Bool?

    private var observationContext = 0

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        togglePlaybackMenuItem = (NSApp.delegate! as! AppDelegate).togglePlaybackMenuItem

        observeUserDefaultsController()

        updateStatusBarItem()

        indicateUnavailability()

        let url = Configuration.shared.shoutcastURL
        audioController = makePlaybackController(url: url)
    }

    deinit {
        unobserveUserDefaultsController()
    }

    private func makePlaybackController(url: URL) -> AudioController {
        let makeSession = { queue in
            return AudioSessionMacOS(queue: queue)
        }

        return AudioController(url: url, delegate: self, delegateQueue: DispatchQueue.main, makeSession: makeSession)
    }

    // MARK: -

    @IBAction func play(_ sender: NSButton) {
        log.info("User pressed play")
        prepareForPlaybackStart()
        audioController.playPause()
    }

    @IBAction func pause(_ sender: NSGestureRecognizer) {
        log.info("User clicked inside the window")
        prepareForPlaybackStop()
        audioController.playPause()
    }

    @IBAction func togglePlayback(_ sender: NSMenuItem) {
        guard togglePlaybackMenuItemIsEnabled == true else {
            log.warning("Ignoring menu toggle because menu is currently intended to be disabled")
            return
        }

        log.info("User invoked menu toggle")
        toggle()
    }

    @objc func toggleStatus(_ sender: NSStatusBarButton) {
        log.info("User clicked status bar toggle")
        if togglePlaybackMenuItemIsEnabled == true {
            toggle()
        }
    }

    private func toggle() {
        isPlaying ? prepareForPlaybackStop() : prepareForPlaybackStart()
        audioController.playPause()
    }

    // MARK: -

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

    // MARK: -

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

    // MARK: Music Menu

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

    // MARK: Status Bar Button

    private func makeStatusButtonItem() -> NSStatusItem {
        let statusBar = NSStatusBar.system

        let item = statusBar.statusItem(withLength: NSStatusItem.squareLength)

        item.image = #imageLiteral(resourceName: "StatusBarButton")
        item.action = #selector(toggleStatus(_:))
        item.target = self

        return item
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
        if showStatusBarIcon {
            if statusItem == nil {
                statusItem = makeStatusButtonItem()
                gleanStatusItemState()
            }
        } else {
            if statusItem != nil {
                removeStatusBarItem()
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

    // MARK: View Menu

    let showStatusBarIconKVOPath = "values.showStatusBarIcon"

    private func observeUserDefaultsController() {
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: showStatusBarIconKVOPath, options: [], context: &observationContext)
    }

    private func unobserveUserDefaultsController() {
        NSUserDefaultsController.shared.removeObserver(self, forKeyPath: showStatusBarIconKVOPath, context: &observationContext)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &observationContext {
            if keyPath == showStatusBarIconKVOPath {
                updateStatusBarItem()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    var showNotifications: Bool {
        return NSUserDefaultsController.shared.defaults.bool(forKey: "showNotifications")
    }

    var showStatusBarIcon: Bool {
        return NSUserDefaultsController.shared.defaults.bool(forKey: "showStatusBarIcon")
    }

    // MARK: Notifications

    private func maybeShowNotification(_ titleComponents: TitleComponents) {
        if showNotifications {
            UserNotification.show(titleComponents)
        }
    }

}
