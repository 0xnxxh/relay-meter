import Foundation

final class AppLogger {
    static let shared = AppLogger()
    let url: URL
    private let queue = DispatchQueue(label: "cpa-menubar.logger")

    private init() {
        url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/cpa-menubar/cpa-menubar.log")
    }

    func info(_ message: String) {
        write("INFO", message)
    }

    func error(_ message: String) {
        write("ERROR", message)
    }

    private func write(_ level: String, _ message: String) {
        let line = "\(Self.timestamp()) [\(level)] \(message)\n"
        queue.async {
            do {
                try FileManager.default.createDirectory(at: self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: self.url.path) {
                    let handle = try FileHandle(forWritingTo: self.url)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: Data(line.utf8))
                    try handle.close()
                } else {
                    try Data(line.utf8).write(to: self.url)
                }
            } catch {
                NSLog("CPA Menubar log failed: %@", String(describing: error))
            }
        }
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
