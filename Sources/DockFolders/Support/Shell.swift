import Foundation

/// Minimal process runner for the handful of system tools we still call
/// (`defaults` for Dock backups, `killall` to restart the Dock, `mdfind` as a lookup fallback).
enum Shell {
    struct Result {
        let status: Int32
        let stdout: String
        let stderr: String
        var ok: Bool { status == 0 }
    }

    @discardableResult
    static func run(_ launchPath: String, _ arguments: [String], timeout: TimeInterval = 30) -> Result {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = arguments
        let out = Pipe(), err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        do {
            try proc.run()
        } catch {
            return Result(status: -1, stdout: "", stderr: "\(error)")
        }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        let deadline = Date().addingTimeInterval(timeout)
        while proc.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if proc.isRunning { proc.terminate() }
        return Result(
            status: proc.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
    }
}
