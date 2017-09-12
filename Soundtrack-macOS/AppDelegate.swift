//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("Launched: \(notification.userInfo ?? [:])")
    }

    func applicationWillTerminate(_ notification: Notification) {
        log.info("Terminated: \(notification.userInfo ?? [:])")
    }
    
}

