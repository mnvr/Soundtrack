//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

class UserNotification {
    class func show(_ titleComponents: TitleComponents) {
        let notification = NSUserNotification()
        notification.title = titleComponents.song
        notification.subtitle = titleComponents.artist
        NSUserNotificationCenter.default.deliver(notification)
    }
}
