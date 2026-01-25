import XCTest
@testable import TimeAttackCore

final class AuthStateTests: XCTestCase {

    // MARK: - isAuthenticated (Parameterized)

    func test_isAuthenticated_returnsExpectedValue() {
        let testCases: [(state: AuthState, expected: Bool)] = [
            (.authenticated(accessToken: "test-token"), true),
            (.unauthenticated, false),
            (.authenticating, false),
            (.error("Some error"), false),
        ]

        for testCase in testCases {
            XCTAssertEqual(
                testCase.state.isAuthenticated,
                testCase.expected,
                "Expected \(testCase.state) isAuthenticated to be \(testCase.expected)"
            )
        }
    }

    // MARK: - accessToken (Parameterized)

    func test_accessToken_returnsExpectedValue() {
        let testCases: [(state: AuthState, expected: String?)] = [
            (.authenticated(accessToken: "my-secret-token-123"), "my-secret-token-123"),
            (.unauthenticated, nil),
            (.authenticating, nil),
            (.error("Authentication failed"), nil),
        ]

        for testCase in testCases {
            XCTAssertEqual(
                testCase.state.accessToken,
                testCase.expected,
                "Expected \(testCase.state) accessToken to be \(String(describing: testCase.expected))"
            )
        }
    }

    // MARK: - Equatable

    func test_equatable_sameAuthenticatedState_areEqual() {
        let state1 = AuthState.authenticated(accessToken: "token")
        let state2 = AuthState.authenticated(accessToken: "token")

        XCTAssertEqual(state1, state2)
    }

    func test_equatable_differentTokens_areNotEqual() {
        let state1 = AuthState.authenticated(accessToken: "token1")
        let state2 = AuthState.authenticated(accessToken: "token2")

        XCTAssertNotEqual(state1, state2)
    }

    func test_equatable_differentStates_areNotEqual() {
        let states: [AuthState] = [
            .unauthenticated,
            .authenticating,
            .authenticated(accessToken: "token"),
            .error("error")
        ]

        for i in 0..<states.count {
            for j in 0..<states.count {
                if i != j {
                    XCTAssertNotEqual(states[i], states[j])
                }
            }
        }
    }
}
