//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

class Configuration {
    static let shared = Configuration()

    private(set) var shoutcastURL: URL? {
        get {
            if let string = UserDefaults.standard.string(forKey: "shoutcastURL") {
                return URL(string: string)
            }
            return nil
        }
        set {
            UserDefaults.standard.set(newValue?.absoluteString, forKey: "shoutcastURL")
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
