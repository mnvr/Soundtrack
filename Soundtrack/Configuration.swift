//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

class Configuration {

    private enum Key: String {
        case shoutcastURLs
    }

    private let csvURL = URL(string: "https://docs.google.com/spreadsheets/d/1eGDZLLi1rsh5Br3vcP8nYGZgAFK1NJM0R2p_TmTzbjY/pub?output=csv")!

    private var shoutcastURLs: [URL]? {
        get {
            let array = UserDefaults.standard.array(forKey: Key.shoutcastURLs.rawValue)
            return array?.flatMap { element in
                if let string = element as? String {
                    return URL(string: string)
                }
                return nil
            }
        }

        set {
            if let strings = newValue?.map({ $0.absoluteString }) {
                UserDefaults.standard.set(strings, forKey: Key.shoutcastURLs.rawValue)
            }
        }
    }

    var shoutcastURL: URL? {
        return shoutcastURLs?.random
    }

    static let shared = Configuration()

    private init() {
        enqueueUpdate()
    }

    private func enqueueUpdate() {
        // FIXME Retry on network errors
        URLSession.shared.dataTask(with: csvURL) { [weak self] (data, response, error) in
            if let error = error {
                log.info("Failed to update configuration from \(self?.csvURL); response = \(response); error = \(error)")
            } else {
                if let data = data, let string = String(data: data, encoding: .utf8) {
                    self?.update(with: string)
                } else {
                    log.info("Skipping unexpected data when updating configuration from \(self?.csvURL); response = \(response); data = \(data)")
                }
            }
        }.resume()
    }

    private func update(with string: String) {
        var result = [URL]()

        for line in string.components(separatedBy: CharacterSet.newlines) {
            if line.isEmpty {
                continue
            }
            let columns = line.components(separatedBy: ",")
            if columns.count != 2 {
                log.info("Ignoring unexpected line [\(line)]")
                continue
            }
            let (key, value) = (columns[0], columns[1])
            log.info("Received configuration item - [\(key)] = [\(value)]")

            if key == "shoutcastURL" {
                if let url = URL(string: value) {
                    result.append(url)
                } else {
                    log.info("Ignoring malformed URL string [\(value)]")
                }
            }
        }

        if !result.isEmpty {
            log.info("Updating SHOUTcast URLs to \(result)")
            shoutcastURLs = result
        }

        NotificationCenter.default.post(name: .ConfigurationDidChange, object: self)
    }

}

// SDK Bug (Xcode 8.2)
//
// The compiler segfaults when we do a
//
//     extension Notification.Name {

extension NSNotification.Name {

    static let ConfigurationDidChange = Notification.Name(rawValue: "ConfigurationDidChange")

}
