//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

extension Bundle {

    var humanReadableVersion: String? {
        guard
            let version = object(forInfoDictionaryKey: "CFBundleShortVersionString"),
            let build = object(forInfoDictionaryKey: "CFBundleVersion")
            else {
                return nil
        }
        return "\(version) (\(build))"
    }

}
