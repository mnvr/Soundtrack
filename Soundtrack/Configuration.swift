//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

class Configuration {

    static let shared = Configuration()

    var shoutcastURL: URL {
        if let urls = userDefaultsShoutcastURLs, let url = urls.random {
            return url
        } else {
            fatalError("Please configure a SHOUTcast URL. You can use the following command: defaults write com.github.mnvr.Soundtrack.Soundtrack-macOS shoutcastURLs -array \"http://your-shoutcast-or-icecast-endpoint.com/\"")
        }
    }

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
