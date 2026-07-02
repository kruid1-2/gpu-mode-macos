import Foundation

struct ProcessResult: Sendable {
    let standardOutput: String
    let standardError: String
    let exitCode: Int32
}

enum ProcessRunnerError: LocalizedError, Sendable {
    case launchFailed(String)
    case timedOut(String)
    case nonZeroExit(code: Int32, standardOutput: String, standardError: String)

    var errorDescription: String? {
        switch self {
        case .launchFailed:
            "系统命令无法启动。"
        case .timedOut:
            "系统命令响应超时。"
        case .nonZeroExit:
            "系统命令执行失败。"
        }
    }

    var diagnosticText: String {
        switch self {
        case .launchFailed(let message), .timedOut(let message):
            message
        case .nonZeroExit(_, let standardOutput, let standardError):
            [standardError, standardOutput]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }
}

final class ProcessRunner: Sendable {
    func run(
        _ executablePath: String,
        arguments: [String] = [],
        timeout: TimeInterval = 10
    ) async throws -> ProcessResult {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                throw ProcessRunnerError.launchFailed(error.localizedDescription)
            }

            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                try await Task.sleep(nanoseconds: 50_000_000)
            }

            if process.isRunning {
                process.terminate()
                try? await Task.sleep(nanoseconds: 200_000_000)
                throw ProcessRunnerError.timedOut("\(executablePath) timed out after \(Int(timeout)) seconds")
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let standardOutput = String(data: outputData, encoding: .utf8) ?? ""
            let standardError = String(data: errorData, encoding: .utf8) ?? ""
            let result = ProcessResult(
                standardOutput: standardOutput,
                standardError: standardError,
                exitCode: process.terminationStatus
            )

            guard result.exitCode == 0 else {
                throw ProcessRunnerError.nonZeroExit(
                    code: result.exitCode,
                    standardOutput: standardOutput,
                    standardError: standardError
                )
            }

            return result
        }.value
    }
}
