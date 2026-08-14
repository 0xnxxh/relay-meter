import Foundation

final class AppLogger {
    static let shared = AppLogger()
    static let maxFileSizeBytes = 2 * 1_024 * 1_024

    let url: URL
    private let queue = DispatchQueue(label: "relay-meter.logger")
    private var handle: FileHandle?
    private var writtenBytes: Int = 0
    private static let timestampFormatter = ISO8601DateFormatter()

    private init() {
        url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/relay-meter/relay-meter.log")
    }

    func info(_ message: String) {
        write("INFO", message)
    }

    func error(_ message: String) {
        write("ERROR", message)
    }

    private func write(_ level: String, _ message: String) {
        let line = "\(Self.timestampFormatter.string(from: Date())) [\(level)] \(message)\n"
        queue.async {
            do {
                let data = Data(line.utf8)
                let handle = try self.openHandle()
                try handle.write(contentsOf: data)
                self.writtenBytes += data.count
                if self.writtenBytes >= Self.maxFileSizeBytes {
                    try self.rotate()
                }
            } catch {
                self.handle = nil
                NSLog("Relay Meter log failed: %@", String(describing: error))
            }
        }
    }

    private func openHandle() throws -> FileHandle {
        if let handle { return handle }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        writtenBytes = Int(try handle.seekToEnd())
        self.handle = handle
        return handle
    }

    /// Keeps one previous log file so a long-running menu bar session cannot grow the log without bound.
    private func rotate() throws {
        try handle?.close()
        handle = nil
        writtenBytes = 0
        let archive = url.deletingPathExtension().appendingPathExtension("1.log")
        let manager = FileManager.default
        if manager.fileExists(atPath: archive.path) {
            try manager.removeItem(at: archive)
        }
        try manager.moveItem(at: url, to: archive)
    }
}
