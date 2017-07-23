//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        logInfo("Launch notification: \(notification)")
        logInfo("Note: All log message timestamps are in UTC")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logInfo("Terminate notification: \(notification)")
    }
    
}

