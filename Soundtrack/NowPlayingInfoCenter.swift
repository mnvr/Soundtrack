//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation
import MediaPlayer

class NowPlayingInfoCenter {

    func setTitle(_ title: String) {
        let titleComponents = TitleComponents(title)

        #if os(macOS)

            let notification = NSUserNotification()
            notification.title = titleComponents.song
            notification.subtitle = titleComponents.artist
            NSUserNotificationCenter.default.deliver(notification)

        #endif

        guard #available(OSX 10.12.2, *) else {
            return
        }

        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = [
            // Workaround:
            // Using the constant MPMediaItemPropertyTitle results in
            // Xcode 8 building an invalid binary for macOS 10.11.

            "title" /*MPMediaItemPropertyTitle*/: titleComponents.song,
            "artist"/*MPMediaItemPropertyArtist*/: titleComponents.artist
        ]
    }

    func clear() {
        guard #available(OSX 10.12.2, *) else {
            return
        }

        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = nil
    }

}
