import Foundation
import GPUModeShared

final class HelperProcessRunner {
    func run(_ command: GPUModeCommandSpec, timeout: TimeInterval = 10) throws -> (String, String, Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executablePath)
        process.arguments = command.arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.2)
            return ("", "命令响应超时。", -1)
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (output, error, process.terminationStatus)
    }
}

final class GPUModeHelper: NSObject, GPUModeHelperProtocol {
    private let runner = HelperProcessRunner()

    func setGPUMode(_ mode: Int, reply: @escaping (Bool, String?) -> Void) {
        guard let commands = GPUModeCommandFactory.setModeCommands(for: mode) else {
            reply(false, "拒绝非法显卡模式。")
            return
        }

        do {
            for command in commands {
                let (_, standardError, exitCode) = try runner.run(command, timeout: 10)
                guard exitCode == 0 else {
                    reply(false, sanitizeError(standardError, fallback: fallbackMessage(for: command)))
                    return
                }
            }
            reply(true, nil)
        } catch {
            reply(false, "无法执行 pmset。")
        }
    }

    func getCurrentMode(reply: @escaping (Int, String?) -> Void) {
        do {
            let (standardOutput, standardError, exitCode) = try runner.run(GPUModeCommandFactory.getModeCommand, timeout: 5)
            guard exitCode == 0 else {
                reply(-1, sanitizeError(standardError, fallback: "无法读取当前显卡模式。"))
                return
            }

            for line in standardOutput.components(separatedBy: .newlines) {
                let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                guard parts.first == "gpuswitch", let rawValue = parts.dropFirst().first, let value = Int(rawValue) else {
                    continue
                }
                reply(value, nil)
                return
            }

            reply(-1, "当前 macOS 或机型可能不支持 gpuswitch。")
        } catch {
            reply(-1, "无法读取当前显卡模式。")
        }
    }

    private func sanitizeError(_ message: String, fallback: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(160))
    }

    private func fallbackMessage(for command: GPUModeCommandSpec) -> String {
        if command.arguments.contains("gpuswitch") {
            return "当前设备可能不支持显卡切换。"
        }

        if command.arguments.contains("lowpowermode") {
            return "低电量模式设置失败。"
        }

        return "pmset 执行失败。"
    }
}

final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let exportedObject = GPUModeHelper()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: GPUModeHelperProtocol.self)
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
    }
}

let listener = NSXPCListener(machServiceName: GPUModeHelperConstants.machServiceName)
listener.setConnectionCodeSigningRequirement(GPUModeHelperConstants.developmentClientRequirement)
let delegate = HelperListenerDelegate()
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
