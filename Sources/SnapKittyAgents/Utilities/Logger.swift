import Foundation
import os

struct SKLogger {
    private static let logger = Logger(subsystem: "com.snapkitty.agents", category: "main")

    static func info(_ msg: String) {
        logger.info("\(msg)")
    }
    static func debug(_ msg: String) {
        logger.debug("\(msg)")
    }
    static func error(_ msg: String) {
        logger.error("\(msg)")
    }
    static func warning(_ msg: String) {
        logger.warning("\(msg)")
    }
}
