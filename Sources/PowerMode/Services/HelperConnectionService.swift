import Foundation
import GPUModeShared

enum HelperConnectionError: LocalizedError, Sendable {
    case invalidMode
    case connectionFailed
    case helperRejected(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidMode:
            "拒绝非法显卡模式。"
        case .connectionFailed:
            "无法连接到 GPU Mode 特权助手。请检查系统设置中的后台项目权限。"
        case .helperRejected(let message):
            message
        case .timedOut:
            "特权助手响应超时。"
        }
    }
}

final class HelperConnectionService: @unchecked Sendable {
    private let lock = NSLock()
    private var connection: NSXPCConnection?

    func setMode(_ mode: Int) async throws {
        guard GPUModeCommandFactory.isValidMode(mode) else {
            throw HelperConnectionError.invalidMode
        }

        try await callSetMode(mode: mode)
    }

    func getCurrentMode() async throws -> Int {
        try await callGetCurrentMode(timeout: 5)
    }

    func verifyConnection() async throws {
        _ = try await callGetCurrentMode(timeout: 2)
    }

    func resetConnection() {
        lock.lock()
        let oldConnection = connection
        connection = nil
        lock.unlock()
        oldConnection?.invalidate()
    }

    private func makeConnectionIfNeeded() -> NSXPCConnection {
        lock.lock()
        defer { lock.unlock() }

        if let connection {
            return connection
        }

        let newConnection = NSXPCConnection(
            machServiceName: GPUModeHelperConstants.machServiceName,
            options: .privileged
        )
        newConnection.remoteObjectInterface = NSXPCInterface(with: GPUModeHelperProtocol.self)
        newConnection.setCodeSigningRequirement(GPUModeHelperConstants.developmentHelperRequirement)
        newConnection.interruptionHandler = { [weak self] in
            self?.resetConnection()
        }
        newConnection.invalidationHandler = { [weak self] in
            self?.resetConnection()
        }
        newConnection.resume()
        connection = newConnection
        return newConnection
    }

    private func callSetMode(mode: Int) async throws {
        let activeConnection = makeConnectionIfNeeded()
        try await withCheckedThrowingContinuation { continuation in
            let resumer = ContinuationResumer<Void>(continuation)
            let proxy = activeConnection.remoteObjectProxyWithErrorHandler { [weak self] _ in
                if resumer.resume(throwing: HelperConnectionError.connectionFailed) {
                    self?.resetConnection()
                }
            }

            guard let helperProxy = proxy as? GPUModeHelperProtocol else {
                resumer.resume(throwing: HelperConnectionError.connectionFailed)
                return
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 8) { [weak self] in
                if resumer.resume(throwing: HelperConnectionError.timedOut) {
                    self?.resetConnection()
                }
            }

            helperProxy.setGPUMode(mode) { success, message in
                if success {
                    resumer.resume(returning: ())
                } else {
                    resumer.resume(throwing: HelperConnectionError.helperRejected(message ?? "特权助手拒绝了请求。"))
                }
            }
        }
    }

    private func callGetCurrentMode(timeout: TimeInterval) async throws -> Int {
        let activeConnection = makeConnectionIfNeeded()
        return try await withCheckedThrowingContinuation { continuation in
            let resumer = ContinuationResumer<Int>(continuation)
            let proxy = activeConnection.remoteObjectProxyWithErrorHandler { [weak self] _ in
                if resumer.resume(throwing: HelperConnectionError.connectionFailed) {
                    self?.resetConnection()
                }
            }

            guard let helperProxy = proxy as? GPUModeHelperProtocol else {
                resumer.resume(throwing: HelperConnectionError.connectionFailed)
                return
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                if resumer.resume(throwing: HelperConnectionError.timedOut) {
                    self?.resetConnection()
                }
            }

            helperProxy.getCurrentMode { mode, message in
                if GPUModeCommandFactory.isValidMode(mode) {
                    resumer.resume(returning: mode)
                } else {
                    resumer.resume(throwing: HelperConnectionError.helperRejected(message ?? "特权助手无法读取当前模式。"))
                }
            }
        }
    }
}

private final class ContinuationResumer<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<T, Error>

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    @discardableResult
    func resume(returning value: T) -> Bool {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return false
        }
        didResume = true
        lock.unlock()
        continuation.resume(returning: value)
        return true
    }

    @discardableResult
    func resume(throwing error: Error) -> Bool {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return false
        }
        didResume = true
        lock.unlock()
        continuation.resume(throwing: error)
        return true
    }
}
