//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

protocol StreamPlayer {

}

protocol StreamPlayerDelegate: class {

    /// This method is invoked after playback has started.

    func streamPlayerDidStartPlayback(_ streamPlayer: StreamPlayer)

    /// This method is invoked both in case the client explicitly
    /// stopped playback by calling the `pause` method on the stream player,
    /// or when playback stopped on its own because the stream player
    /// encountered an error.

    func streamPlayerDidStopPlayback(_ streamPlayer: StreamPlayer)

    func streamPlayer(_ streamPlayer: StreamPlayer, didChangeSong title: String)
    
}
