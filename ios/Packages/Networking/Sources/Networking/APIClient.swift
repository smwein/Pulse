import Foundation

public struct APIClient: Sendable {
    public let config: APIClientConfig
    private let session: URLSession

    public init(config: APIClientConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Streams parsed SSE events from the worker proxy. Each yielded event is a complete
    /// SSE record. Errors propagate via the AsyncThrowingStream.
    public func streamEvents(request: AnthropicRequest) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var urlRequest = URLRequest(url: config.workerURL)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.setValue(config.deviceToken, forHTTPHeaderField: "X-Device-Token")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        throw APIClientError.badStatus(http.statusCode)
                    }

                    var parser = SSEStreamParser()
                    var bucket = Data()
                    bucket.reserveCapacity(4096)
                    for try await byte in bytes {
                        bucket.append(byte)
                        if bucket.count >= 1024 {
                            for evt in parser.feed(bucket) { continuation.yield(evt) }
                            bucket.removeAll(keepingCapacity: true)
                        }
                    }
                    if !bucket.isEmpty {
                        for evt in parser.feed(bucket) { continuation.yield(evt) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

public enum APIClientError: Error, Equatable, Sendable {
    case badStatus(Int)
    case decoding(String)
}

extension APIClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .badStatus(0):
            return "Workout generation is not configured in this build."
        case .badStatus(400):
            return "The workout request was malformed. Please try again."
        case .badStatus(401), .badStatus(403):
            return "The workout service rejected this device token. Rebuild the app with the matching DEVICE_TOKEN."
        case .badStatus(429):
            return "The workout service is rate limited. Please wait a minute and try again."
        case .badStatus(let status) where status >= 500:
            return "The workout service is temporarily unavailable (\(status)). Please try again."
        case .badStatus(let status):
            return "The workout service returned HTTP \(status)."
        case .decoding(let message):
            return "The workout service returned a response Pulse couldn't read: \(message)"
        }
    }
}
