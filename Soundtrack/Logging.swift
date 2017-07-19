// Logging.swift
// Soundtrack
//
// Copyright (c) 2017 Manav Rathi
//
// Apache License, Version 2.0 (see LICENSE)

import Foundation

/// Writes a log entry.

public func logInfo(_ item: @autoclosure () -> Any, tag: String? = nil, file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {

    struct MyDateFormatter {
        static let shared = { () -> DateFormatter in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter
        }()
    }

    let date = Date()
    let formattedDate = MyDateFormatter.shared.string(from: date)
    let fileName = (String(describing: file) as NSString).lastPathComponent

    let message = "\(formattedDate) \(fileName):\(line) \(function) \(item())"
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

public func logDebug(_ item: @autoclosure () -> Any, file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {
    #if DEBUG
        logInfo(item, tag: "DEBUG", file: file, line: line, function: function)
    #endif
}

/// Writes a log entry (always) and terminates execution of debug builds.

public func logWarning(_ item: @autoclosure () -> Any = String(), file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {
    let message = "\(item())"
    logInfo(message, tag: "WARNING", file: file, line: line, function: function)
    assertionFailure("\(function) \(message)", file: file, line: line)
}

/// Invokes `logWarning` when `condition` is `true`.

public func logWarningIf(_ condition: Bool, _ item: @autoclosure () -> Any = String(), file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {
    if condition {
        logWarning(item, file: file, line: line, function: function)
    }
}

/// Invokes `logWarning` when `condition` is `false`.

public func logWarningUnless(_ condition: Bool, _ item: @autoclosure () -> Any = String(), file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {
    if !condition {
        logWarning(item, file: file, line: line, function: function)
    }
}
