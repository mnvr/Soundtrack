//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit

extension UIApplicationState: CustomStringConvertible {

    var description: String {
        switch self {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .background: return "Background"
        }
    }

}
