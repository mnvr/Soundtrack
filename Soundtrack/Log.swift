//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

let log = Log()

class Log {

    /// Writes a log entry.

    func info(_ message: String) {
        NSLog(message)
    }

    /// Writes a log entry (always) and terminates execution of debug builds.

    func warning(_ message: String = "", file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {
        detailedInfo(message, tag: "WARNING", file: file, line: line, function: function)
        assertionFailure("\(function) \(message)", file: file, line: line)
    }

    /// Writes a log entry only during execution of debug builds.

    func debug(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {
        #if DEBUG
            detailedInfo(message(), tag: "DEBUG", file: file, line: line, function: function)
        #endif
    }

    func trace(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {
        #if DEBUG && LOG_TRACE
            detailedInfo(message(), tag: "TRACE", file: file, line: line, function: function)
        #endif
    }

    private func detailedInfo(_ message: String, tag: String, file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {
        let fileName = (String(describing: file) as NSString).lastPathComponent
        info("\(tag) \(fileName):\(line) \(function) \(message)")
    }
}
