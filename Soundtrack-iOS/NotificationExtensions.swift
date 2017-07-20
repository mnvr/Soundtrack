//
//  NotificationExtensions.swift
//  Soundtrack-iOS
//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, Version 2.0 (see LICENSE)
//

import Foundation

extension Notification {

    /// Extract an enum from the notification's user info dictionary.

    public func enumForKey<E: RawRepresentable>(_ key: String) -> E? {
        guard
            let userInfo = userInfo,
            let value = userInfo[key],
            let rawValue = value as? E.RawValue else {
            return nil
        }
        return E(rawValue: rawValue)
    }

}

