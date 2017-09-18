//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Cocoa

class ViewController: NSViewController, AudioControllerDelegate, StreamPlayerDelegate {

    var audioController: AudioController!
    var defaultWindowTitle: String!

    @IBOutlet weak var playButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        playButton.title = NSLocalizedString("Loading", comment: "")
        playButton.isEnabled = false

        let url = Configuration.shared.shoutcastURL
        audioController = makePlaybackController(url: url)
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        if defaultWindowTitle == nil {
            defaultWindowTitle = view.window!.title
        }
    }

    private func makePlaybackController(url: URL) -> AudioController {
        let makeSession = { queue in
            return AudioSessionMacOS(queue: queue)
        }

        return AudioController(url: url, delegate: self, delegateQueue: DispatchQueue.main, makeSession: makeSession)
    }

    @IBAction func togglePlayPause(_ sender: NSButton) {
        log.info("User toggled playback state")
        audioController.playPause()
    }

    func audioControllerDidBecomeAvailable(_ audioController: AudioController) {
        playButton.title = NSLocalizedString("Play", comment: "")
        playButton.isEnabled = true
    }

    func audioControllerDidBecomeUnavailable(_ audioController: AudioController) {
        playButton.title = NSLocalizedString("...", comment: "")
        playButton.isEnabled = false
    }

    func streamPlayerDidStartPlayback(_ streamPlayer: StreamPlayer) {
        playButton.title = NSLocalizedString("Pause", comment: "")
    }

    func streamPlayerDidStopPlayback(_ streamPlayer: StreamPlayer) {
        playButton.title = NSLocalizedString("Play", comment: "")
        resetWindowTitle()
    }

    func streamPlayer(_ streamPlayer: StreamPlayer, didChangeSong title: String) {
        setWindowTitle(title)
    }

    // MARK: Window Title

    private func setWindowTitle(_ title: String) {
        view.window!.title = title
    }

    private func resetWindowTitle() {
        view.window!.title = defaultWindowTitle
    }

}
