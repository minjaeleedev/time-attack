import XCTest
@testable import TimeAttackCore

final class AuthStateTests: XCTestCase {

    // MARK: - isAuthenticated

    func test_isAuthenticated_whenAuthenticated_returnsTrue() {
        // Given
        let state = AuthState.authenticated(accessToken: "test-token")

        // When
        let result = state.isAuthenticated

        // Then
        XCTAssertTrue(result)
    }

    func test_isAuthenticated_whenUnauthenticated_returnsFalse() {
        // Given
        let state = AuthState.unauthenticated

        // When
        let result = state.isAuthenticated

        // Then
        XCTAssertFalse(result)
    }

    func test_isAuthenticated_whenAuthenticating_returnsFalse() {
        // Given
        let state = AuthState.authenticating

        // When
        let result = state.isAuthenticated

        // Then
        XCTAssertFalse(result)
    }

    func test_isAuthenticated_whenError_returnsFalse() {
        // Given
        let state = AuthState.error("Some error")

        // When
        let result = state.isAuthenticated

        // Then
        XCTAssertFalse(result)
    }

    // MARK: - accessToken

    func test_accessToken_whenAuthenticated_returnsToken() {
        // Given
        let expectedToken = "my-secret-token-123"
        let state = AuthState.authenticated(accessToken: expectedToken)

        // When
        let result = state.accessToken

        // Then
        XCTAssertEqual(result, expectedToken)
    }

    func test_accessToken_whenUnauthenticated_returnsNil() {
        // Given
        let state = AuthState.unauthenticated

        // When
        let result = state.accessToken

        // Then
        XCTAssertNil(result)
    }

    func test_accessToken_whenAuthenticating_returnsNil() {
        // Given
        let state = AuthState.authenticating

        // When
        let result = state.accessToken

        // Then
        XCTAssertNil(result)
    }

    func test_accessToken_whenError_returnsNil() {
        // Given
        let state = AuthState.error("Authentication failed")

        // When
        let result = state.accessToken

        // Then
        XCTAssertNil(result)
    }

    // MARK: - Equatable

    func test_equatable_sameAuthenticatedState_areEqual() {
        // Given
        let state1 = AuthState.authenticated(accessToken: "token")
        let state2 = AuthState.authenticated(accessToken: "token")

        // Then
        XCTAssertEqual(state1, state2)
    }

    func test_equatable_differentTokens_areNotEqual() {
        // Given
        let state1 = AuthState.authenticated(accessToken: "token1")
        let state2 = AuthState.authenticated(accessToken: "token2")

        // Then
        XCTAssertNotEqual(state1, state2)
    }

    func test_equatable_differentStates_areNotEqual() {
        // Given
        let states: [AuthState] = [
            .unauthenticated,
            .authenticating,
            .authenticated(accessToken: "token"),
            .error("error")
        ]

        // Then
        for i in 0..<states.count {
            for j in 0..<states.count {
                if i != j {
                    XCTAssertNotEqual(states[i], states[j])
                }
            }
        }
    }
}
