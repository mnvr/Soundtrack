//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Cocoa

class WindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()

        window!.titlebarAppearsTransparent = true
        window!.isMovableByWindowBackground = true
    }

}
