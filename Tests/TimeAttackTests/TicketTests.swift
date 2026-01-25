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

    private func makeTicketWithId(_ id: String) -> Ticket {
        Ticket(
            id: id,
            identifier: "TEST-\(id)",
            title: "Test Ticket \(id)",
            url: "https://linear.app/test/\(id)",
            state: "In Progress",
            linearEstimate: nil,
            localEstimate: nil,
            priority: 1,
            updatedAt: Date(),
            dueDate: nil
        )
    }

    private func makeTicketWithChildren(
        id: String = "parent-id",
        children: [Ticket]
    ) -> Ticket {
        Ticket(
            id: id,
            identifier: "TEST-PARENT",
            title: "Parent Ticket",
            url: "https://linear.app/test/parent",
            state: "In Progress",
            linearEstimate: nil,
            localEstimate: nil,
            priority: 1,
            updatedAt: Date(),
            dueDate: nil,
            children: children
        )
    }

    // MARK: - displayEstimate

    func test_displayEstimate_withLocalEstimate_returnsFormattedTime() {
        let testCases: [(localEstimate: TimeInterval, expected: String)] = [
            (60, "1m"),
            (3660, "1h 1m"),
            (7200, "2h 0m"),
            (0, "0m"),
            (1800, "30m"),
            (5400, "1h 30m"),
        ]

        for testCase in testCases {
            let ticket = makeTicket(localEstimate: testCase.localEstimate)
            XCTAssertEqual(
                ticket.displayEstimate,
                testCase.expected,
                "Expected localEstimate \(testCase.localEstimate) to display as '\(testCase.expected)'"
            )
        }
    }

    func test_displayEstimate_withLinearEstimate_returnsPoints() {
        let testCases: [(linearEstimate: Int, expected: String)] = [
            (0, "0 pts"),
            (1, "1 pts"),
            (3, "3 pts"),
            (5, "5 pts"),
            (8, "8 pts"),
        ]

        for testCase in testCases {
            let ticket = makeTicket(linearEstimate: testCase.linearEstimate)
            XCTAssertEqual(
                ticket.displayEstimate,
                testCase.expected,
                "Expected linearEstimate \(testCase.linearEstimate) to display as '\(testCase.expected)'"
            )
        }
    }

    func test_displayEstimate_withBothEstimates_prefersLocalEstimate() {
        let ticket = makeTicket(linearEstimate: 5, localEstimate: 1800)

        XCTAssertEqual(ticket.displayEstimate, "30m")
    }

    func test_displayEstimate_withNoEstimate_returnsNoEstimate() {
        let ticket = makeTicket()

        XCTAssertEqual(ticket.displayEstimate, "No estimate")
    }

    // MARK: - dueDateStatus

    func test_dueDateStatus_withNoDueDate_returnsNone() {
        let ticket = makeTicket()

        XCTAssertEqual(ticket.dueDateStatus, .none)
    }

    func test_dueDateStatus_withPastDueDate_returnsOverdue() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let ticket = makeTicket(dueDate: pastDate)

        if case .overdue(let days) = ticket.dueDateStatus {
            XCTAssertEqual(days, 3)
        } else {
            XCTFail("Expected .overdue status, got \(ticket.dueDateStatus)")
        }
    }

    func test_dueDateStatus_withTodayDueDate_returnsToday() {
        let today = Date()
        let ticket = makeTicket(dueDate: today)

        XCTAssertEqual(ticket.dueDateStatus, .today)
    }

    func test_dueDateStatus_withSoonDueDate_returnsSoon() {
        let testCases: [(daysFromNow: Int, expectedDays: Int)] = [
            (1, 1),
            (2, 2),
            (3, 3),
        ]

        for testCase in testCases {
            let futureDate = Calendar.current.date(
                byAdding: .day, value: testCase.daysFromNow, to: Date())!
            let ticket = makeTicket(dueDate: futureDate)

            if case .soon(let days) = ticket.dueDateStatus {
                XCTAssertEqual(
                    days,
                    testCase.expectedDays,
                    "Expected .soon(\(testCase.expectedDays)) for \(testCase.daysFromNow) days from now"
                )
            } else {
                XCTFail(
                    "Expected .soon status for \(testCase.daysFromNow) days, got \(ticket.dueDateStatus)"
                )
            }
        }
    }

    func test_dueDateStatus_withNormalDueDate_returnsNormal() {
        let weekLater = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let ticket = makeTicket(dueDate: weekLater)

        if case .normal(let days) = ticket.dueDateStatus {
            XCTAssertEqual(days, 7)
        } else {
            XCTFail("Expected .normal status, got \(ticket.dueDateStatus)")
        }
    }

    // MARK: - hasChildren

    func test_hasChildren_withNoChildren_returnsFalse() {
        // Given
        let ticket = makeTicket()

        // When & Then
        XCTAssertFalse(ticket.hasChildren)
    }

    func test_hasChildren_withChildren_returnsTrue() {
        // Given
        let child = makeTicket()
        let parent = makeTicketWithChildren(children: [child])

        // When & Then
        XCTAssertTrue(parent.hasChildren)
    }

    // MARK: - allTickets

    func test_allTickets_withNoChildren_returnsSelfOnly() {
        // Given
        let ticket = makeTicket()

        // When
        let allTickets = ticket.allTickets

        // Then
        XCTAssertEqual(allTickets.count, 1)
        XCTAssertEqual(allTickets.first?.id, ticket.id)
    }

    func test_allTickets_withChildren_includesChildrenInOrder() {
        // Given
        let child1 = makeTicketWithId("child-1")
        let child2 = makeTicketWithId("child-2")
        let parent = makeTicketWithChildren(children: [child1, child2])

        // When
        let allTickets = parent.allTickets

        // Then
        XCTAssertEqual(allTickets.count, 3)
        XCTAssertEqual(allTickets[0].id, parent.id)
        XCTAssertEqual(allTickets[1].id, "child-1")
        XCTAssertEqual(allTickets[2].id, "child-2")
    }

    func test_allTickets_withNestedChildren_includesGrandchildrenRecursively() {
        // Given
        let grandchild = makeTicketWithId("grandchild-1")
        let child = makeTicketWithChildren(id: "child-1", children: [grandchild])
        let parent = makeTicketWithChildren(children: [child])

        // When
        let allTickets = parent.allTickets

        // Then
        XCTAssertEqual(allTickets.count, 3)
        XCTAssertEqual(allTickets[0].id, parent.id)
        XCTAssertEqual(allTickets[1].id, "child-1")
        XCTAssertEqual(allTickets[2].id, "grandchild-1")
    }
}
