import Foundation

public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let baseDelay: Double   // seconds; nth retry waits baseDelay * 3^n

    public init(maxAttempts: Int = 3, baseDelay: Double = 1.0) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
    }

    public static let `default` = RetryPolicy()

    public func run<T>(_ operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do { return try await operation() }
            catch let error where Self.isRetryable(error) {
                lastError = error
                if attempt < maxAttempts - 1 {
                    let delay = baseDelay * pow(3.0, Double(attempt))
                    if delay > 0 {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            } catch {
                throw error
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    public static func isRetryable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return true
            default: return false
            }
        }
        if let apiError = error as? APIClientError {
            if case let .badStatus(code) = apiError {
                return code >= 500
            }
        }
        return false
    }
}
