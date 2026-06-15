//
//  DebugLogger.swift
//  Process
//
//  Points d’entrée no-op pour ne pas laisser de bruit console en production.
//

import Foundation

enum DebugLogger {
    static func log(_ message: String, category: String = "General") {}
    static func verbose(_ message: String, category: String = "Verbose") {}
    static func error(_ message: String, category: String = "Error") {}
    static func success(_ message: String, category: String = "Success") {}
    static func warning(_ message: String, category: String = "Warning") {}
}

@inline(__always)
func debugLog(_ message: String) {}

@inline(__always)
func verboseLog(_ message: String) {}
