//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // MARK: App Life Cycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        log.info("Launch Options: \(launchOptions)")

        if application.applicationState == .inactive {
            log.info("Application is launching into the foreground")
        } else if application.applicationState == .background {
            log.info("Application is launching into the background")
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        log.info("Application did become active")
    }

    func applicationWillResignActive(_ application: UIApplication) {
        log.info("Application will resign active")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        log.info("Application did enter background")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        log.info("Application will enter foreground")
    }

}

