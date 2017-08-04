//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("Launch notification: \(notification)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        log.info("Terminate notification: \(notification)")
    }
    
}

