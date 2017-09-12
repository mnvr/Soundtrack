//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit

class ViewController: UIViewController, AudioControllerDelegate, StreamPlayerDelegate {

    var audioController: AudioController!

    @IBOutlet weak var playButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        playButton.setTitle(NSLocalizedString("Loading", comment: ""), for: .normal)
        playButton.isEnabled = false

        maybeMakePlaybackController()
        observe(.ConfigurationDidChange, with: #selector(maybeMakePlaybackController))
    }

    @objc private func maybeMakePlaybackController() {
        if let url = Configuration.shared.shoutcastURL, audioController == nil {
            audioController = makePlaybackController(url: url)
        }
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

}
