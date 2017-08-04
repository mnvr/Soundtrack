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
        log.info("Application State: \(application.applicationState)")

        if application.applicationState == .inactive {
            log.info("Application is launching into the foreground")

        } else if application.applicationState == .background {
            log.info("Application is launching into the background")

        } else {
            log.warning("Unexpected application state \(application.applicationState) at launch")
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        log.info("Application State: \(application.applicationState)")
        log.warningUnless(application.applicationState == .active)

    }

    func applicationWillResignActive(_ application: UIApplication) {
        log.info("Application will transition to an inactive state")

    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        log.info("Application State: \(application.applicationState)")
        log.warningUnless(application.applicationState == .background)

    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        log.info("Application will transition to an inactive state")

    }

}

