//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Cocoa

class ViewController: NSViewController, AudioControllerDelegate, StreamPlayerDelegate {

    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var titleStackView: NSStackView!
    @IBOutlet weak var songTextField: NSTextField!
    @IBOutlet weak var artistTextField: NSTextField!
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
    }

    func streamPlayerDidStopPlayback(_ streamPlayer: StreamPlayer) {
        playButton.isEnabled = true
        fadeIn(playButton)

        togglePlaybackMenuItemTitle = menuTitlePlay()
        togglePlaybackMenuItemIsEnabled = true
    }

    func streamPlayer(_ streamPlayer: StreamPlayer, didChangeSong title: String) {
        setTitle(title)
    }

    private func setTitle(_ title: String) {
        let maybeFadeInTitle = { [weak self] in
            if !title.isEmpty {
                self?.setTitleComponents(title)
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

    private func setTitleComponents(_ title: String) {
        let titleComponents = TitleComponents(title)
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
