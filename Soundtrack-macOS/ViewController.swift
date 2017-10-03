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

    private var audioController: AudioController!

    override func viewDidLoad() {
        super.viewDidLoad()

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

    @IBAction func play(_ sender: NSButton) {
        log.info("User pressed play")
        indicateUnavailability()
        audioController.playPause()
    }

    @IBAction func click(_ sender: NSGestureRecognizer) {
        log.info("User clicked inside the window")
        indicateUnavailability()
        audioController.playPause()
    }

    // MARK: State Changes

    private func indicatePlaybackReadiness() {
        playButton.isEnabled = true
        playButton.isHidden = false
        progressIndicator.stopAnimation(self)
        titleTextField.isHidden = true
        resetTitle()
        clickGestureRecognizer.isEnabled = false

    }

    private func indicateUnavailability() {
        playButton.isEnabled = false
        playButton.isHidden = true
        progressIndicator.startAnimation(self)
        titleTextField.isHidden = true
        resetTitle()
        clickGestureRecognizer.isEnabled = false
    }

    private func indicatePlayback() {
        playButton.isEnabled = false
        playButton.isHidden = true
        progressIndicator.stopAnimation(self)
        resetTitle()
        titleTextField.isHidden = false
        clickGestureRecognizer.isEnabled = true
    }

    private func setTitle(_ title: String) {
        titleTextField.stringValue = title
    }

    private func resetTitle() {
        setTitle("")
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
        indicatePlaybackReadiness()
    }

    func streamPlayer(_ streamPlayer: StreamPlayer, didChangeSong title: String) {
        setTitle(title)
    }

}
