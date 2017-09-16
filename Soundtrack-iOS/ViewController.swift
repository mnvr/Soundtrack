//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit

class ViewController: UIViewController, AudioControllerDelegate, StreamPlayerDelegate, UIPageViewControllerDataSource {

    var audioController: AudioController!

    @IBOutlet weak var playButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        playButton.setTitle(NSLocalizedString("Loading", comment: ""), for: .normal)
        playButton.isEnabled = false

        let url = Configuration.shared.shoutcastURL
        audioController = makePlaybackController(url: url)
    }

    private func makePlaybackController(url: URL) -> AudioController {
        let makeSession = { queue in
            return AudioSessionIOS(queue: queue)
        }

        return AudioController(url: url, delegate: self, delegateQueue: DispatchQueue.main, makeSession: makeSession)
    }

    @IBAction func togglePlayPause(_ sender: UIButton) {
        log.info("User toggled playback state")
        audioController.playPause()
    }

    func audioControllerDidBecomeAvailable(_ audioController: AudioController) {
        playButton.setTitle(NSLocalizedString("Play", comment: ""), for: .normal)
        playButton.isEnabled = true
    }

    func audioControllerDidBecomeUnavailable(_ audioController: AudioController) {
        playButton.setTitle(NSLocalizedString("...", comment: ""), for: .normal)
        playButton.isEnabled = false
    }

    func streamPlayerDidStartPlayback(_ streamPlayer: StreamPlayer) {
        playButton.setTitle(NSLocalizedString("Pause", comment: ""), for: .normal)
    }

    func streamPlayerDidStopPlayback(_ streamPlayer: StreamPlayer) {
        playButton.setTitle(NSLocalizedString("Play", comment: ""), for: .normal)
    }

    func streamPlayer(_ streamPlayer: StreamPlayer, didChangeSong title: String) {
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
