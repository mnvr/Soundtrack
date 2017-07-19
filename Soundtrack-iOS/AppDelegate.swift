// AppDelegate.swift
// Soundtrack iOS
//
// Copyright (c) 2017 Manav Rathi
//
// Apache License, Version 2.0 (see LICENSE)

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // MARK: App Life Cycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        logInfo("Launch Options: \(launchOptions)")
        logInfo("Application State: \(application.applicationState)")
        logInfo("Note: All log message timestamps are in UTC")

        if application.applicationState == .inactive {
            logInfo("Application is launching into the foreground")

        } else if application.applicationState == .background {
            logInfo("Application is launching into the background")

        } else {
            logWarning("Unexpected application state \(application.applicationState) at launch")
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        logInfo("Application State: \(application.applicationState)")
        logWarningUnless(application.applicationState == .active)

    }

    func applicationWillResignActive(_ application: UIApplication) {
        logInfo("Application will transition to an inactive state")

    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        logInfo("Application State: \(application.applicationState)")
        logWarningUnless(application.applicationState == .background)

    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        logInfo("Application will transition to an inactive state")

    }

}

extension UIApplicationState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .background: return "Background"
        }
    }
}
