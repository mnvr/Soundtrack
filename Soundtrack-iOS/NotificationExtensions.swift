//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

extension Notification {

    /// Extract an enum from the notification's user info dictionary.

    func enumForKey<E: RawRepresentable>(_ key: String) -> E? {
        guard
            let userInfo = userInfo,
            let value = userInfo[key],
            let rawValue = value as? E.RawValue else {
            return nil
        }
        return E(rawValue: rawValue)
    }

}

