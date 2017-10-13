//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import MediaPlayer

class RemoteCommandCenter {

    weak var delegate: RemoteCommandCenterDelegate?

    private var playCommandTarget: Any?
    private var pauseCommandTarget: Any?
    private var stopCommandTarget: Any?
    private var togglePlayPauseCommandTarget: Any?

    init() {
        guard #available(OSX 10.12.2, *) else {
            return
        }

        let center = MPRemoteCommandCenter.shared()
        playCommandTarget = attachToggle(to: center.playCommand)
        pauseCommandTarget = attachToggle(to: center.pauseCommand)
        stopCommandTarget = attachToggle(to: center.stopCommand)
        togglePlayPauseCommandTarget = attachToggle(to: center.togglePlayPauseCommand)
    }

    @available(OSX 10.12.2, *)
    private func attachToggle(to command: MPRemoteCommand) -> Any {
        return command.addTarget { [weak self]commandEvent -> MPRemoteCommandHandlerStatus in
            if let strongSelf = self {
                strongSelf.delegate?.remoteCommandCenterDidTogglePlayPause(strongSelf)
            }
            return .success
        }
    }

    deinit {
        guard #available(OSX 10.12.2, *) else {
            return
        }

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(playCommandTarget)
        center.pauseCommand.removeTarget(pauseCommandTarget)
        center.pauseCommand.removeTarget(stopCommandTarget)
        center.togglePlayPauseCommand.removeTarget(togglePlayPauseCommandTarget)
    }

}

protocol RemoteCommandCenterDelegate: class {

    func remoteCommandCenterDidTogglePlayPause(_ remoteCommandCenter: RemoteCommandCenter)

}
