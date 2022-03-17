import Foundation
import MessageUI

/**
 * Used to manage all app logs. Same usage as print function. Please do not use print(). See shortend below
 ``````````````
  LOG("my message", category: mycategory)
  WLOG("my message") -> category = .warning
  ELOG("my message") -> category = .error
 ``````````````
 */


// MARK: Public interfaceConsoleLogger
public enum LogCategory: String {
    case none      = "   "
    case info      = "ℹ️ "
    case warning   = "⚠️ "
    case error     = "⛔️ "
    case success   = "✅ "
    case likeABoss = "😎 "
    case test      = "❔ "
    case request   = "➡️ "
    case response  = "⬅️ "
    case start     = "🚀 "
    case end       = "🏁 "
    case package   = "📦 "
    case delete    = "🗑 "
    case user      = "👤 "
    case tracking  = "🏷 "
}

class TLogger: NSObject, UINavigationControllerDelegate, MFMailComposeViewControllerDelegate {

    var loggerViewDisplayed: Bool = false
    var logMessages: [String] = Array()
    
    // MARK: Singleton
    static let sharedInstance: TLogger = TLogger()


    /// Get the log content
    static var logs: String? {
        if let logFilename = sharedInstance.logFilename {
            return (try? String(contentsOf: logFilename, encoding: String.Encoding.utf8)) ?? ""
        } else {
            return nil
        }
        
    }

    // Notifications in App
    static let logAdded = "logAdded"
    
    enum LogAddedInfo {
        static let log = "log"
    }
    
    /// Logs configuration by enabling or not them
    public func configure(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    /// Boolean indicates if logging is enabled
    private var isEnabled: Bool = false
    
    /// Used to print message. Use shortend instead of this method
    ///
    /// - Parameters:
    ///   - message: message to print
    ///   - category: category of the message
    func log(message: Any..., category: LogCategory) {
        guard isEnabled else { return }
        let fullMessage = category.rawValue
            .appending(self.getString(from: message))
            .replacingOccurrences(of: "\n", with: "\n   ")
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: Self.logAdded),
            object: nil,
            userInfo: [Self.LogAddedInfo.log: fullMessage]
        )
        logMessages.append(fullMessage)
        if let logFile = self.logFile, let data = fullMessage.appending("\n").data(using: .utf8) {
            logFile.write(data)
        }
        
        print(fullMessage)
    }
    
    
    /// Sned the logs by email
    func sendDebugLogs() {
        let files = self.listAllLogs()

        if files.count > 1 {
            let ac = UIAlertController(
                title: "debugLog.sendMultiple.title".localizedString,
                message: String(
                    format: "debugLog.sendMultiple.message".localizedString,
                    files.count
                ),
                preferredStyle: .actionSheet
            )
            ac.addAction(
                UIAlertAction(
                    title: "debugLog.sendMultiple.sendAll".localizedString,
                    style: .default,
                    handler: self.sendAllLogs
                )
            )
            ac.addAction(
                UIAlertAction(
                    title: "debugLog.sendMultiple.sendLast".localizedString,
                    style: .default,
                    handler: self.sendLastLog
                )
            )
            ac.addAction(
                UIAlertAction(
                    title: "debugLog.sendMultiple.sendCurrent".localizedString,
                    style: .default,
                    handler: self.sendCurrentLog
                )
            )

            ac.addAction(
                UIAlertAction(
                    title: "common.cancel".localizedString, style: .cancel, handler: nil
                )
            )

            if ac.popoverPresentationController != nil {
                // don't present alert controller for iPad
                return
            }

            if let rvc = UIApplication.shared.keyWindow?.rootViewController {
                rvc.present(ac, animated: true, completion: nil)
            }
        } else if files.count > 0 {
            self.sendCurrentLog(UIAlertAction(title: "Log", style: .default, handler: nil))
        }

    }

    // MARK: Properties
    lazy private var logDirectory: URL? = {
        if UserDefaults.standard.bool(forKey: "debug_log") == false {
            return nil
        }

        guard let docsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                           in: .userDomainMask).first else {
                                                            return nil
        }

        let logDirectory = docsDirectory.appendingPathComponent("debugLogs")
        do {
            try FileManager.default.createDirectory(at: logDirectory,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        } catch {
            LOG("Cannot create log directory at \(logDirectory)", category: .error)
            return nil
        }
        return logDirectory
    }()

    lazy private var logFilename: URL? = {
        if UserDefaults.standard.bool(forKey: "debug_log") == false {
            return nil
        }

        guard let logDirectory = self.logDirectory else {
            return nil
        }
        if let projectName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as? String {
            return logDirectory
                .appendingPathComponent("\(projectName)-log-\(round(Date().timeIntervalSince1970)).txt")
        } else {
            return logDirectory.appendingPathComponent("log.txt")
        }

    }()

    lazy private var logFile: FileHandle? = {
        if UserDefaults.standard.bool(forKey: "debug_log") == false {
            return nil
        }

        guard let fn = self.logFilename else {
            return nil
        }

        let fileHandle: FileHandle?
        do {
            FileManager.default.createFile(atPath: fn.path, contents: nil, attributes: nil)
            fileHandle = try FileHandle(forWritingTo: fn)
        } catch {
            LOG("Cannot create file handle for writing at \(fn.path): \(error)", category: .error)
            return nil
        }
        fileHandle?.seekToEndOfFile()
        LOG("Debug log written to \(fn.path)", category: .success)
        return fileHandle

    }()
    
    lazy private var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ssSS"
        return dateFormatter
    }()

    private func listAllLogs() -> [String] {
        guard let dir = self.logDirectory else { return [] }

        var files: [String]
        do {
            files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        } catch { return [] }
        files.sort()

        return files
    }

    private func getString(from obj: Any, withoutTime: Bool = false) -> String {
        if let o = obj as? String {
            return withoutTime ? o : dateFormatter.string(from: Date()) + " " + o
        } else if let o = obj as? [Any] {
            var msg = withoutTime ? "" : dateFormatter.string(from: Date()) + " "
            for item in o {
                msg += self.getString(from: item, withoutTime: true) + " "
            }
            return msg
        } else {
            return withoutTime ? String(describing: obj) : dateFormatter.string(from: Date()) + " " + String(describing: obj)
        }
    }
    
    private func sendAllLogs(_ action: UIAlertAction) {
        self.sendLogs(self.listAllLogs())
    }
 
    private func sendLastLog(_ action: UIAlertAction) {
        let files = listAllLogs()
        if files.count >= 2 {
            self.sendLogs([files[files.count - 2]])
        }
    }

    private func sendCurrentLog(_ action: UIAlertAction) {
        if let f = self.logFilename {
            self.sendLogs([f.lastPathComponent])
        }
    }

    private var logsToDelete: [String] = []

    private func sendLogs(_ filenames: [String]) {
        guard let dir = self.logDirectory else { return }

        let mailer = MFMailComposeViewController()
        mailer.delegate = self
        mailer.mailComposeDelegate = self
        mailer.setSubject("debugLog.mail.subject".localizedString)
        mailer.setToRecipients("debugLog.mail.recipients".localizedString.components(separatedBy: ";"))
        logsToDelete = []
        filenames.forEach { filename in
            var data: Data
            do {
                data = try Data(contentsOf: dir.appendingPathComponent(filename))
            } catch {
                return
            }
            mailer.addAttachmentData(data, mimeType: "text/plain", fileName: filename)

            if filename != self.logFilename?.lastPathComponent {
                logsToDelete.append(filename)
            }
        }

        if let rvc = UIApplication.shared.keyWindow?.rootViewController {
            rvc.present(mailer, animated: true, completion: nil)
        }
    }

    internal func mailComposeController(_ controller: MFMailComposeViewController,
                                        didFinishWith result: MFMailComposeResult,
                                        error: Error?) {

        controller.dismiss(animated: true) {

            switch result {
            case .sent:

                // TODO ask to delete sent logs (except current)

                let ac = UIAlertController(
                    title: nil,
                    message: "debugLog.deleteSent.message".localizedString,
                    preferredStyle: .actionSheet
                )
                ac.addAction(
                    UIAlertAction(
                        title: "debugLog.deleteSent.yes".localizedString,
                        style: .destructive,
                        handler: { _ in
                        guard let dir = self.logDirectory else { return }
                        self.logsToDelete.forEach { filename in
                            do {
                                try FileManager.default.removeItem(at: dir.appendingPathComponent(filename))
                            } catch {
                                return
                            }
                        }
                        self.logsToDelete = []

                        }
                    )
                )
                ac.addAction(
                    UIAlertAction(
                        title: "debugLog.deleteSent.no".localizedString, style: .cancel, handler: nil
                    )
                )

                if let rvc = UIApplication.shared.keyWindow?.rootViewController {
                    rvc.present(ac, animated: true, completion: nil)
                }

            default: break
            }
        }
    }
}


/// Shorthand
#if DEBUG
public func LOG(_ message: String, _ level: LogLevel = .debug, remoteLogger: RemoteLogger? = nil) {
    TLogger.sharedInstance.log(message: message, category: .none)
    if let remoteLogger = remoteLogger {
        remoteLogger.log(message, level: level)
    }
}
public func LOG(_ message: String, _ category: LogCategory = .none) {
    TLogger.sharedInstance.log(message: message, category: category)
}
public func LOG(_ message: Any, category: LogCategory = .none) {
    TLogger.sharedInstance.log(message: message, category: category)
}
public func WLOG(_ message: Any) {
    TLogger.sharedInstance.log(message: message, category: .warning)
}
public func ELOG(_ message: Any) {
    TLogger.sharedInstance.log(message: message, category: .error)
}

#else
public func LOG(_ message: String, _ level: LogLevel = .debug, remoteLogger: RemoteLogger? = nil) {
    if let remoteLogger = remoteLogger {
        remoteLogger.log(message, level: level)
    }
}
public func LOG(_ message: String, _ category: LogCategory = .none) {}
public func LOG(_ message: Any, category: LogCategory = .none) {}
public func WLOG(_ message: Any) {}
public func ELOG(_ message: Any) {}
#endif

fileprivate extension String {
    /// Used to localize string
    var localizedString: String {
        return NSLocalizedString(self, comment: self)
    }
}
