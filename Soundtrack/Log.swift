//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

let log = Log()

class Log {

    let dateFormatter = { () -> DateFormatter in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    init() {
        info("Namaste! The timestamps of log messages are in UTC")
    }

    /// Writes a log entry.

    func info(_ item: Any, tag: String? = nil, file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {

        let date = Date()
        let formattedDate = dateFormatter.string(from: date)
        let fileName = (String(describing: file) as NSString).lastPathComponent

        let message = "\(formattedDate) \(fileName):\(line) \(function) \(item)"
        let taggedMessage: String
        if let tag = tag {
            taggedMessage = "\(tag) " + message
        } else {
            taggedMessage = message
        }

        //NSLog(taggedMessage)
        print(taggedMessage)
    }

    /// Writes a log entry only during execution of debug builds.

    func debug(_ item: @autoclosure () -> Any, file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {
        #if DEBUG
            info(item(), tag: "DEBUG", file: file, line: line, function: function)
        #endif
    }

    func trace(_ item: @autoclosure () -> Any, file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {
        #if DEBUG && LOG_TRACE
            info(item(), tag: "TRACE", file: file, line: line, function: function)
        #endif
    }

    /// Writes a log entry (always) and terminates execution of debug builds.

    func warning(_ item: Any = String(), file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {
        let message = "\(item)"
        info(message, tag: "WARNING", file: file, line: line, function: function)
        assertionFailure("\(function) \(message)", file: file, line: line)
    }

}
