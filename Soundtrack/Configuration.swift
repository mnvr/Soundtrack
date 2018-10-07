//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

class Configuration {
    static let shared = Configuration()
    private let userDefaults = UserDefaults.standard

    private(set) var shoutcastURL: URL? {
        get {
            if let string = userDefaults.string(forKey: "shoutcastURL") {
                return URL(string: string)
            }
            return nil
        }
        set {
            userDefaults.set(newValue?.absoluteString, forKey: "shoutcastURL")
        }
    }

    var hideNotifications: Bool {
        get {
            return userDefaults.bool(forKey: "hideNotifications")
        }
        set {
            userDefaults.set(newValue, forKey: "hideNotifications")
        }
    }

    var hideStatusBarIcon: Bool {
        get {
            return userDefaults.bool(forKey: "hideStatusBarIcon")
        }
        set {
            return userDefaults.set(newValue, forKey: "hideStatusBarIcon")
        }
    }

    var hideDockIcon: Bool {
        get {
            if hideStatusBarIcon {
                return true
            }
            return userDefaults.bool(forKey: "hideDockIcon")
        }
        set {
            return userDefaults.set(newValue, forKey: "hideDockIcon")
        }
    }

    func updateShoutcastURL(playlistURL: URL, completion: @escaping (Bool) -> Void) {
        let task = URLSession.shared.dataTask(with: playlistURL) { [weak self] data, urlResponse, error in
            if let data = data, let string = String(data: data, encoding: .utf8) {
                self?.updateShoutcastURL(playlistContents: string, completion: completion)
            } else {
                NSLog("Failed to obtain contents of playlist from url \(playlistURL): \(String(describing: error))")
                completion(false)
            }
        }
        task.resume()
    }

    private func updateShoutcastURL(playlistContents: String, completion: @escaping (Bool) -> Void) {
        NSLog("Got playlist contents: \(playlistContents)")
        var url: URL?
        for line in playlistContents.split(separator: "\n") {
            let components = line.split(separator: "=")
            if let key = components.first, let value = components.last,
                key == "File1" {
                url = URL(string: String(value))
                break
            }
        }

        if let url = url {
            NSLog("Was able to extract shoutcast URL from playlist: \(url)")
            shoutcastURL = url
            completion(true)
        } else {
            completion(false)
        }
    }
}
