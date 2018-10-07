//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit

class ViewController: UIViewController, AudioControllerDelegate, StreamPlayerDelegate {
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var songLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet var tapGestureRecognizer: UITapGestureRecognizer!

    var audioController: AudioController?

    private var isPlaying: Bool = false
    private var currentPlaybackAttempt: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        indicateUnavailability()

        if let url = Configuration.shared.shoutcastURL {
            audioController = makePlaybackController(url: url)
        }
    }

    private func makePlaybackController(url: URL) -> AudioController {
        let makeSession = { queue in
            return AudioSessionIOS(queue: queue)
        }

        return AudioController(url: url, delegate: self, delegateQueue: DispatchQueue.main, makeSession: makeSession)
    }

    // MARK: -

    @IBAction func play(_ sender: UIButton) {
        log.info("User pressed play")
        prepareForPlaybackStart()
        audioController?.playPause()
    }

    @IBAction func pause(_ sender: UITapGestureRecognizer) {
        log.info("User tapped inside the window")
        prepareForPlaybackStop()
        audioController?.playPause()
    }

    // MARK: -

    private func indicateUnavailability() {
        isPlaying = false

        playButton.isEnabled = false
        playButton.isHidden = false

        activityIndicator.stopAnimating()

        titleStackView.isHidden = true

        tapGestureRecognizer.isEnabled = false
    }

    func audioControllerDidBecomeAvailable(_ audioController: AudioController) {
        playButton.isEnabled = true
    }

    func audioControllerDidBecomeUnavailable(_ audioController: AudioController) {
        indicateUnavailability()
    }

    private func prepareForPlaybackStart() {
        playButton.isEnabled = false
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
                activityIndicator.startAnimating()
            }
        }
    }

    private func maybeCancelProgressIndicator() {
        currentPlaybackAttempt += 1

        activityIndicator.stopAnimating()
    }

    func streamPlayerDidStartPlayback(_ streamPlayer: StreamPlayer) {
        isPlaying = true

        maybeCancelProgressIndicator()

        tapGestureRecognizer.isEnabled = true
    }

    private func prepareForPlaybackStop() {
        tapGestureRecognizer.isEnabled = false
    }

    func audioControllerWillStopPlayback(_ audioController: AudioController) {
        prepareForPlaybackStop()

        maybeCancelProgressIndicator()

        isPlaying = false

        fadeOutTitleComponents()
    }

    func streamPlayerDidStopPlayback(_ streamPlayer: StreamPlayer) {
        playButton.isEnabled = true
        fadeIn(playButton)
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
            fadeOutTitleComponents() {
                maybeFadeInTitle()
            }
        }
    }

    private func setTitleComponents(_ title: String) {
        let titleComponents = TitleComponents(title)
        songLabel.text = titleComponents.song
        artistLabel.text = titleComponents.artist

        fadeInTitleComponents()
    }

    // MARK: -

    private func fadeOut(_ view: UIView, duration: TimeInterval = 2, then: (() -> Void)? = nil) {
        UIView.transition(with: view, duration: duration, options: .transitionCrossDissolve, animations: {
            view.isHidden = true
        }, completion: { completed in
            if let then = then {
                then()
            }
        })
    }

    private func fadeIn(_ view: UIView, duration: TimeInterval = 2) {
        UIView.transition(with: view, duration: duration, options: .transitionCrossDissolve, animations: {
            view.isHidden = false
        }, completion: nil)
    }

    // Animations did not work when we directly modify the hidden property of
    // the UIStackView. As a workaround, we embed the stack view inside an
    // empty container, and pass the superview to `UIView.transition`.

    private func fadeOutTitleComponents(duration: TimeInterval = 2, then: (() -> Void)? = nil) {
        let containerView = titleStackView.superview!
        let stackView = titleStackView!
        UIView.transition(with: containerView, duration: duration, options: .transitionCrossDissolve, animations: {
            stackView.isHidden = true
        }, completion: { completed in
            if let then = then {
                then()
            }
        })
    }

    private func fadeInTitleComponents(duration: TimeInterval = 2) {
        let containerView = titleStackView.superview!
        let stackView = titleStackView!
        UIView.transition(with: containerView, duration: duration, options: .transitionCrossDissolve, animations: {
            stackView.isHidden = false
        }, completion: nil)
    }
}
