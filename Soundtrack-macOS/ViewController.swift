// ViewController.swift
// Soundtrack macOS
//
// Copyright (c) 2017 Manav Rathi
//
// Apache License, Version 2.0 (see LICENSE)

import Cocoa
import AVFoundation
import AVKit

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let playerView = AVPlayerView(frame: self.view.bounds)
        let url = Bundle.main.url(forResource: "MN - Going Down.wav", withExtension: nil)
        playerView.player = AVPlayer(url: url!)
        self.view.addSubview(playerView)
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

}
