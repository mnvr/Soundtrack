//
//  UIApplicationStateExtensions.swift
//  Soundtrack-iOS
//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, Version 2.0 (see LICENSE)
//

import UIKit

extension UIApplicationState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .background: return "Background"
        }
    }
}
