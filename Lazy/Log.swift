//
//  OSLog.swift
//  Lazy
//
//  Created by Tobias Schröpf on 22.05.19.
//  Copyright © 2019 Tobias Schröpf. All rights reserved.
//

import Foundation
import os.log

// https://www.avanderlee.com/debugging/oslog-unified-logging/
extension OSLog {
    fileprivate static var subsystem = Bundle.main.bundleIdentifier!
}

enum Log {
    /// Logs the view cycles like viewDidLoad.
    static let viewmodel = OSLog(subsystem: OSLog.subsystem, category: "viewmodel")

    static func log(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, log: OSLog = .default, type: OSLogType = .default, _ args: CVarArg...) {
        os_log(message, dso: dso, log: log, type: type, args)
    }

    static func debug(log: OSLog = .default, _ message: StaticString, _ args: CVarArg...) {
        os_log(message, log: log, type: .debug, args)
    }

    static func info(log: OSLog = .default, _ message: StaticString, _ args: CVarArg...) {
        os_log(message, log: log, type: .info, args)
    }

    static func error(log: OSLog = .default, _ message: StaticString, _ args: CVarArg...) {
        os_log(message, log: log, type: .error, args)
    }

    static func fault(log: OSLog = .default, _ message: StaticString, _ args: CVarArg...) {
        os_log(message, log: log, type: .fault, args)
    }
}
