import XCTest
@testable import TimeAttackCore

final class TicketTests: XCTestCase {

    // MARK: - Helper

    private func makeTicket(
        linearEstimate: Int? = nil,
        localEstimate: TimeInterval? = nil
    ) -> Ticket {
        Ticket(
            id: "test-id",
            identifier: "TEST-1",
            title: "Test Ticket",
            url: "https://linear.app/test",
            state: "In Progress",
            linearEstimate: linearEstimate,
            localEstimate: localEstimate,
            priority: 1,
            updatedAt: Date()
        )
    }

    // MARK: - displayEstimate with localEstimate

    func test_displayEstimate_withLocalEstimate60Seconds_returns1m() {
        // Given
        let ticket = makeTicket(localEstimate: 60)

        // When
        let result = ticket.displayEstimate

        // Then
        XCTAssertEqual(result, "1m")
    }

    func test_displayEstimate_withLocalEstimate3660Seconds_returns1h1m() {
        // Given
        let ticket = makeTicket(localEstimate: 3660)

        // When
        let result = ticket.displayEstimate

        // Then
        XCTAssertEqual(result, "1h 1m")
    }

    func test_displayEstimate_withLocalEstimate7200Seconds_returns2h0m() {
        // Given
        let ticket = makeTicket(localEstimate: 7200)

        // When
        let result = ticket.displayEstimate

        // Then
        XCTAssertEqual(result, "2h 0m")
    }

    func test_displayEstimate_withLocalEstimate0Seconds_returns0m() {
        // Given
        let ticket = makeTicket(localEstimate: 0)

        // When
        let result = ticket.displayEstimate

        // Then
        XCTAssertEqual(result, "0m")
    }

    // MARK: - displayEstimate with linearEstimate

    func test_displayEstimate_withLinearEstimate3_returns3pts() {
        // Given
        let ticket = makeTicket(linearEstimate: 3)

        // When
        let result = ticket.displayEstimate

        // Then
        XCTAssertEqual(result, "3 pts")
    }

    func test_displayEstimate_withLinearEstimate0_returns0pts() {
        // Given
        let ticket = makeTicket(linearEstimate: 0)

        // When
        let result = ticket.displayEstimate

        // Then
        XCTAssertEqual(result, "0 pts")
    }

    // MARK: - displayEstimate priority (localEstimate > linearEstimate)

    func test_displayEstimate_withBothEstimates_prefersLocalEstimate() {
        // Given
        let ticket = makeTicket(linearEstimate: 5, localEstimate: 1800)

        // When
        let result = ticket.displayEstimate

        // Then
        XCTAssertEqual(result, "30m")
    }

    // MARK: - displayEstimate with no estimate

    func test_displayEstimate_withNoEstimate_returnsNoEstimate() {
        // Given
        let ticket = makeTicket()

        // When
        let result = ticket.displayEstimate

        // Then
        XCTAssertEqual(result, "No estimate")
    }
}
