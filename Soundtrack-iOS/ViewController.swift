//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit

class ViewController: UIViewController, AudioControllerDelegate, StreamPlayerDelegate, UIPageViewControllerDataSource {

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var songLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet var tapGestureRecognizer: UITapGestureRecognizer!

    var audioController: AudioController!

    private var isPlaying: Bool = false
    private var currentPlaybackAttempt: Int = 0

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        indicateUnavailability()

        let url = Configuration.shared.shoutcastURL
        audioController = makePlaybackController(url: url)
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
        audioController.playPause()
    }

    @IBAction func pause(_ sender: UITapGestureRecognizer) {
        log.info("User tapped inside the window")
        prepareForPlaybackStop()
        audioController.playPause()
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

        fadeOut(titleStackView)
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
                if let strongSelf = self {
                    strongSelf.setTitleComponents(title)
                    strongSelf.fadeIn(strongSelf.titleStackView)
                }
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
        songLabel.text = titleComponents.song
        artistLabel.text = titleComponents.artist
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

    private func fadeIn(_ view: UIView, duration: TimeInterval = 2, then: (() -> Void)? = nil) {
        UIView.transition(with: view, duration: duration, options: .transitionCrossDissolve, animations: {
            view.isHidden = false
        }, completion: { completed in
            if let then = then {
                then()
            }
        })
    }

    // MARK: Page View Controller - Children

    enum StoryboardIdentifier: String {
        case empty, about
    }

    lazy var emptyViewController: UIViewController = self.makeViewController(identifier: .empty)
    lazy var aboutViewController: UIViewController = self.makeViewController(identifier: .about)

    func makeViewController(identifier: StoryboardIdentifier) -> UIViewController {
        let identifier = identifier.rawValue
        return storyboard!.instantiateViewController(withIdentifier: identifier)
    }

    // MARK: Page View Controller

    private var presentationIndex = 0

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let pageViewController = segue.destination as? UIPageViewController {
            configurePageViewController(pageViewController)
        }
    }

    private func configurePageViewController(_ pageViewController: UIPageViewController) {
        pageViewController.setViewControllers([emptyViewController], direction: .forward, animated: false, completion: nil)
        pageViewController.dataSource = self
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if viewController == emptyViewController {
            presentationIndex = 1
            return aboutViewController
        } else {
            return nil
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {

        // The order of these checks is important to avoid initializing the
        // aboutViewController lazy property by unnecessarily accessing it.

        if viewController == emptyViewController {
            return nil
        } else {
            presentationIndex = 0
            return emptyViewController
        }
    }

    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return 2
    }

    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return presentationIndex
    }

}
