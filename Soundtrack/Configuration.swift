//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

class Configuration {

    static let shared = Configuration()

    var shoutcastURL: URL {
        return (userDefaultsShoutcastURLs ?? preconfiguredShoutcastURLs).random!
    }

    // MARK: -

    // There are corresponding ATS exceptions for these in the Info Plists.

    private let preconfiguredShoutcastURLs = [
        URL(string: "http://ice1.somafm.com/dronezone-128-aac")!,
        URL(string: "http://ice2.somafm.com/dronezone-128-aac")!
    ]

    private enum UserDefaultsKey: String {
        case shoutcastURLs
    }

    private var userDefaultsShoutcastURLs: [URL]? {
        let key = UserDefaultsKey.shoutcastURLs.rawValue
        let array = UserDefaults.standard.array(forKey: key)
        return array?.flatMap { element in
            if let string = element as? String {
                return URL(string: string)
            }
            return nil
        }
    }

}
