import XCTest
@testable import TimeAttackCore

final class TicketTests: XCTestCase {

    // MARK: - Helper

    private func makeTicket(
        linearEstimate: Int? = nil,
        localEstimate: TimeInterval? = nil,
        dueDate: Date? = nil
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
            updatedAt: Date(),
            dueDate: dueDate
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

    // MARK: - dueDateStatus

    func test_dueDateStatus_withNoDueDate_returnsNone() {
        // Given
        let ticket = makeTicket()

        // When
        let status = ticket.dueDateStatus

        // Then
        XCTAssertEqual(status, .none)
    }

    func test_dueDateStatus_withPastDueDate_returnsOverdue() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let ticket = makeTicket(dueDate: pastDate)

        // When
        let status = ticket.dueDateStatus

        // Then
        if case .overdue(let days) = status {
            XCTAssertEqual(days, 3)
        } else {
            XCTFail("Expected .overdue status, got \(status)")
        }
    }

    func test_dueDateStatus_withTodayDueDate_returnsToday() {
        // Given
        let today = Date()
        let ticket = makeTicket(dueDate: today)

        // When
        let status = ticket.dueDateStatus

        // Then
        XCTAssertEqual(status, .today)
    }

    func test_dueDateStatus_withTomorrowDueDate_returnsSoon() {
        // Given
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let ticket = makeTicket(dueDate: tomorrow)

        // When
        let status = ticket.dueDateStatus

        // Then
        if case .soon(let days) = status {
            XCTAssertEqual(days, 1)
        } else {
            XCTFail("Expected .soon status, got \(status)")
        }
    }

    func test_dueDateStatus_with3DaysLeft_returnsSoon() {
        // Given
        let threeDaysLater = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let ticket = makeTicket(dueDate: threeDaysLater)

        // When
        let status = ticket.dueDateStatus

        // Then
        if case .soon(let days) = status {
            XCTAssertEqual(days, 3)
        } else {
            XCTFail("Expected .soon status, got \(status)")
        }
    }

    func test_dueDateStatus_with7DaysLeft_returnsNormal() {
        // Given
        let weekLater = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let ticket = makeTicket(dueDate: weekLater)

        // When
        let status = ticket.dueDateStatus

        // Then
        if case .normal(let days) = status {
            XCTAssertEqual(days, 7)
        } else {
            XCTFail("Expected .normal status, got \(status)")
        }
    }

    // MARK: - DueDateStatus displayText

    func test_dueDateStatus_displayText_overdue1Day() {
        // Given
        let status = DueDateStatus.overdue(days: 1)

        // When & Then
        XCTAssertEqual(status.displayText, "1일 지남")
    }

    func test_dueDateStatus_displayText_overdue3Days() {
        // Given
        let status = DueDateStatus.overdue(days: 3)

        // When & Then
        XCTAssertEqual(status.displayText, "3일 지남")
    }

    func test_dueDateStatus_displayText_today() {
        // Given
        let status = DueDateStatus.today

        // When & Then
        XCTAssertEqual(status.displayText, "오늘 마감")
    }

    func test_dueDateStatus_displayText_soon1Day() {
        // Given
        let status = DueDateStatus.soon(days: 1)

        // When & Then
        XCTAssertEqual(status.displayText, "내일 마감")
    }

    func test_dueDateStatus_displayText_soon2Days() {
        // Given
        let status = DueDateStatus.soon(days: 2)

        // When & Then
        XCTAssertEqual(status.displayText, "2일 남음")
    }

    func test_dueDateStatus_displayText_normal() {
        // Given
        let status = DueDateStatus.normal(days: 10)

        // When & Then
        XCTAssertEqual(status.displayText, "10일 남음")
    }

    func test_dueDateStatus_displayText_none() {
        // Given
        let status = DueDateStatus.none

        // When & Then
        XCTAssertEqual(status.displayText, "")
    }

    // MARK: - DueDateStatus color

    func test_dueDateStatus_color_overdue_isRed() {
        XCTAssertEqual(DueDateStatus.overdue(days: 1).color, "red")
    }

    func test_dueDateStatus_color_today_isOrange() {
        XCTAssertEqual(DueDateStatus.today.color, "orange")
    }

    func test_dueDateStatus_color_soon_isYellow() {
        XCTAssertEqual(DueDateStatus.soon(days: 2).color, "yellow")
    }

    func test_dueDateStatus_color_normal_isSecondary() {
        XCTAssertEqual(DueDateStatus.normal(days: 10).color, "secondary")
    }

    func test_dueDateStatus_color_none_isClear() {
        XCTAssertEqual(DueDateStatus.none.color, "clear")
    }
}
