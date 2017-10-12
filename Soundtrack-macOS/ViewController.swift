//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Cocoa

class ViewController: NSViewController, AudioControllerDelegate, StreamPlayerDelegate {

    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var clickGestureRecognizer: NSClickGestureRecognizer!
    @IBOutlet weak var togglePlaybackMenuItem: NSMenuItem!

    private var audioController: AudioController!

    private var isPlaying: Bool = false
    private var currentPlaybackAttempt: Int = 0

    private var togglePlaybackMenuItemTitle: String?
    private var togglePlaybackMenuItemIsEnabled: Bool?

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        togglePlaybackMenuItem = (NSApp.delegate! as! AppDelegate).togglePlaybackMenuItem

        indicateUnavailability()

        let url = Configuration.shared.shoutcastURL
        audioController = makePlaybackController(url: url)
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
        initiatePlayback()
        audioController.playPause()
    }

    @IBAction func click(_ sender: NSGestureRecognizer) {
        log.info("User clicked inside the window")
        initiatePause()
        audioController.playPause()
    }

    @IBAction func togglePlayback(_ sender: NSMenuItem) {
        log.info("User invoked menu toggle")
        isPlaying ? initiatePause() : initiatePlayback()
        audioController.playPause()
    }

    // MARK: -

    private func indicateUnavailability() {
        isPlaying = false

        playButton.isEnabled = false
        playButton.isHidden = false

        progressIndicator.stopAnimation(self)

        titleTextField.isHidden = true

        clickGestureRecognizer.isEnabled = false

        togglePlaybackMenuItemTitle = menuTitlePlay()
        togglePlaybackMenuItemIsEnabled = false
    }

    private func indicatePlaybackReadiness() {
        playButton.isEnabled = true
        togglePlaybackMenuItemIsEnabled = true
    }

    private func initiatePlayback() {
        playButton.isEnabled = false

        let playbackAttempt = currentPlaybackAttempt
        currentPlaybackAttempt += 1

        fadeOut(playButton) { [weak self] in
            self?.maybeShowProgressIndicatorForPlaybackAttempt(playbackAttempt)
        }

        togglePlaybackMenuItemIsEnabled = false
    }

    private func maybeShowProgressIndicatorForPlaybackAttempt(_ playbackAttempt: Int) {
        if !isPlaying {
            if playbackAttempt == currentPlaybackAttempt {
                progressIndicator.startAnimation(self)
            }
        }
    }

    private func indicatePlayback() {
        isPlaying = true

        progressIndicator.stopAnimation(self)

        clickGestureRecognizer.isEnabled = true

        togglePlaybackMenuItemTitle = menuTitlePause()
        togglePlaybackMenuItemIsEnabled = true
    }

    private func initiatePause() {
        isPlaying = false

        fadeOut(titleTextField)

        clickGestureRecognizer.isEnabled = false

        togglePlaybackMenuItemIsEnabled = false
    }

    private func indicatePause() {
        playButton.isEnabled = true
        fadeIn(playButton)

        togglePlaybackMenuItemTitle = menuTitlePlay()
        togglePlaybackMenuItemIsEnabled = true
    }

    private func setTitle(_ title: String) {
        let maybeFadeInTitle = { [weak self] in
            if !title.isEmpty {
                if let strongSelf = self, let titleTextField = strongSelf.titleTextField {
                    titleTextField.stringValue = title
                    strongSelf.fadeIn(titleTextField)
                }
            }
        }

        if titleTextField.isHidden {
            maybeFadeInTitle()
        } else {
            fadeOut(titleTextField) {
                maybeFadeInTitle()
            }
        }
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

    // MARK: Audio Controller

    func audioControllerDidBecomeAvailable(_ audioController: AudioController) {
        indicatePlaybackReadiness()
    }

    func audioControllerDidBecomeUnavailable(_ audioController: AudioController) {
        indicateUnavailability()
    }

    func streamPlayerDidStartPlayback(_ streamPlayer: StreamPlayer) {
        indicatePlayback()
    }

    func streamPlayerDidStopPlayback(_ streamPlayer: StreamPlayer) {
        if isPlaying {
            initiatePause()
        }
        indicatePause()
    }

    func streamPlayer(_ streamPlayer: StreamPlayer, didChangeSong title: String) {
        setTitle(title)
    }

    // MARK: -

    private func menuTitlePlay() -> String {
        return NSLocalizedString("Play", comment: "Menu Item - Music > Play")
    }

    private func menuTitlePause() -> String {
        return NSLocalizedString("Pause", comment: "Menu Item - Music > Pause")
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(togglePlayback(_:)) {
            if let title = togglePlaybackMenuItemTitle {
                menuItem.title = title
            }
            return togglePlaybackMenuItemIsEnabled ?? false
        }

        return super.validateMenuItem(menuItem)
    }

}
