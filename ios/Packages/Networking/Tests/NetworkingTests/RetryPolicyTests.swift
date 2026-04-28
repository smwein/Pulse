import XCTest
@testable import Networking

final class RetryPolicyTests: XCTestCase {
    func test_succeedsOnFirstAttempt() async throws {
        var attempts = 0
        let result = try await RetryPolicy.default.run {
            attempts += 1
            return 42
        }
        XCTAssertEqual(result, 42)
        XCTAssertEqual(attempts, 1)
    }

    func test_retriesUpToMaxAttemptsOnFailure() async {
        var attempts = 0
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0)
        do {
            _ = try await policy.run { () -> Int in
                attempts += 1
                throw URLError(.timedOut)
            }
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(attempts, 3)
        }
    }

    func test_doesNotRetryNonRetryableErrors() async {
        var attempts = 0
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0)
        do {
            _ = try await policy.run { () -> Int in
                attempts += 1
                throw APIClientError.badStatus(401)
            }
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(attempts, 1)
        }
    }
}
