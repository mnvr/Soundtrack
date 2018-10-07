//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Cocoa

class WindowController: NSWindowController, NSWindowDelegate {
    override func windowDidLoad() {
        super.windowDidLoad()

        window?.titlebarAppearsTransparent = true
        window?.isMovableByWindowBackground = true
    }

    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
        let defaultSize = NSSize(width: 480, height: 270)

        let currentOrigin = window.frame.origin
        let currentHeight = window.frame.size.height
        let currentTopLeft = currentOrigin.y + currentHeight
        let newOrigin = NSPoint(x: currentOrigin.x, y: currentTopLeft - defaultSize.height)

        return NSRect(origin: newOrigin, size: defaultSize)
    }
}
