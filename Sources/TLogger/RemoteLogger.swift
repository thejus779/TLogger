
import Foundation

public enum LogLevel {
    case debug
    case critical
}

public protocol Logger {
    func log(_ message: String, level: LogLevel, file: String, method: String, lineNumber: Int)
}

public final class RemoteLogger {

    let loggers: [Logger]

    init(loggers: [Logger]) {
        self.loggers = loggers
    }

    func log(
        _ message: String,
        level: LogLevel = .debug,
        file: String = #function,
        method: String = #file,
        lineNumber: Int = #line
    ) {
        loggers.forEach {
            $0.log(message, level: level, file: file, method: method, lineNumber: lineNumber)
        }
    }
}
