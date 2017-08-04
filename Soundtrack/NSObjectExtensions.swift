//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

extension NSObject {

    /// Invoke `selector` when any object posts a notification with the given
    /// name to the default notification center.
    ///
    /// If your app targets iOS 9.0 and later or macOS 10.11 and later,
    /// you don't need to unregister an observer in its deallocation method.

    func observe(_ name: Notification.Name, with selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
    }

}
