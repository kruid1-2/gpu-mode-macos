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

        try await performWithRetry { proxy in
            try await self.callSetMode(proxy: proxy, mode: mode)
        }
    }

    func getCurrentMode() async throws -> Int {
        try await performWithRetry { proxy in
            try await self.callGetCurrentMode(proxy: proxy)
        }
    }

    func resetConnection() {
        lock.lock()
        let oldConnection = connection
        connection = nil
        lock.unlock()
        oldConnection?.invalidate()
    }

    private func performWithRetry<T>(_ operation: @escaping (GPUModeHelperProtocol) async throws -> T) async throws -> T {
        do {
            return try await operation(remoteProxy())
        } catch {
            resetConnection()
            do {
                return try await operation(remoteProxy())
            } catch let retryError as HelperConnectionError {
                throw retryError
            } catch {
                throw HelperConnectionError.connectionFailed
            }
        }
    }

    private func remoteProxy() throws -> GPUModeHelperProtocol {
        let activeConnection = makeConnectionIfNeeded()
        let proxy = activeConnection.remoteObjectProxyWithErrorHandler { [weak self] _ in
            self?.resetConnection()
        }

        guard let helperProxy = proxy as? GPUModeHelperProtocol else {
            throw HelperConnectionError.connectionFailed
        }

        return helperProxy
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

    private func callSetMode(proxy: GPUModeHelperProtocol, mode: Int) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let resumer = ContinuationResumer<Void>(continuation)
            DispatchQueue.global().asyncAfter(deadline: .now() + 8) {
                resumer.resume(throwing: HelperConnectionError.timedOut)
            }

            proxy.setGPUMode(mode) { success, message in
                if success {
                    resumer.resume(returning: ())
                } else {
                    resumer.resume(throwing: HelperConnectionError.helperRejected(message ?? "特权助手拒绝了请求。"))
                }
            }
        }
    }

    private func callGetCurrentMode(proxy: GPUModeHelperProtocol) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            let resumer = ContinuationResumer<Int>(continuation)
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                resumer.resume(throwing: HelperConnectionError.timedOut)
            }

            proxy.getCurrentMode { mode, message in
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

    func resume(returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else {
            return
        }
        didResume = true
        continuation.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else {
            return
        }
        didResume = true
        continuation.resume(throwing: error)
    }
}
