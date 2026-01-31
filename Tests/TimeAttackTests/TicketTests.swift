import XCTest

@testable import TimeAttackCore

final class TicketTests: XCTestCase {

    // MARK: - Helper

    private func makeTicket(
        externalEstimate: Int? = nil,
        localEstimate: TimeInterval? = nil,
        dueDate: Date? = nil
    ) -> Ticket {
        Ticket(
            id: "test-id",
            identifier: "TEST-1",
            title: "Test Ticket",
            state: "In Progress",
            source: .linear(issueId: "test-id", url: "https://linear.app/test"),
            priority: 1,
            updatedAt: Date(),
            dueDate: dueDate,
            localEstimate: localEstimate,
            externalEstimate: externalEstimate
        )
    }

    private func makeTicketWithId(_ id: String) -> Ticket {
        Ticket(
            id: id,
            identifier: "TEST-\(id)",
            title: "Test Ticket \(id)",
            state: "In Progress",
            source: .linear(issueId: id, url: "https://linear.app/test/\(id)"),
            priority: 1,
            updatedAt: Date()
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
            state: "In Progress",
            source: .linear(issueId: id, url: "https://linear.app/test/parent"),
            priority: 1,
            updatedAt: Date(),
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

    func test_displayEstimate_withExternalEstimate_returnsPoints() {
        let testCases: [(externalEstimate: Int, expected: String)] = [
            (0, "0 pts"),
            (1, "1 pts"),
            (3, "3 pts"),
            (5, "5 pts"),
            (8, "8 pts"),
        ]

        for testCase in testCases {
            let ticket = makeTicket(externalEstimate: testCase.externalEstimate)
            XCTAssertEqual(
                ticket.displayEstimate,
                testCase.expected,
                "Expected externalEstimate \(testCase.externalEstimate) to display as '\(testCase.expected)'"
            )
        }
    }

    func test_displayEstimate_withBothEstimates_prefersLocalEstimate() {
        let ticket = makeTicket(externalEstimate: 5, localEstimate: 1800)

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
        let ticket = makeTicket()

        XCTAssertFalse(ticket.hasChildren)
    }

    func test_hasChildren_withChildren_returnsTrue() {
        let child = makeTicket()
        let parent = makeTicketWithChildren(children: [child])

        XCTAssertTrue(parent.hasChildren)
    }

    // MARK: - allTickets

    func test_allTickets_withNoChildren_returnsSelfOnly() {
        let ticket = makeTicket()

        let allTickets = ticket.allTickets

        XCTAssertEqual(allTickets.count, 1)
        XCTAssertEqual(allTickets.first?.id, ticket.id)
    }

    func test_allTickets_withChildren_includesChildrenInOrder() {
        let child1 = makeTicketWithId("child-1")
        let child2 = makeTicketWithId("child-2")
        let parent = makeTicketWithChildren(children: [child1, child2])

        let allTickets = parent.allTickets

        XCTAssertEqual(allTickets.count, 3)
        XCTAssertEqual(allTickets[0].id, parent.id)
        XCTAssertEqual(allTickets[1].id, "child-1")
        XCTAssertEqual(allTickets[2].id, "child-2")
    }

    func test_allTickets_withNestedChildren_includesGrandchildrenRecursively() {
        let grandchild = makeTicketWithId("grandchild-1")
        let child = makeTicketWithChildren(id: "child-1", children: [grandchild])
        let parent = makeTicketWithChildren(children: [child])

        let allTickets = parent.allTickets

        XCTAssertEqual(allTickets.count, 3)
        XCTAssertEqual(allTickets[0].id, parent.id)
        XCTAssertEqual(allTickets[1].id, "child-1")
        XCTAssertEqual(allTickets[2].id, "grandchild-1")
    }

    // MARK: - TaskSource

    func test_isLocal_withLocalSource_returnsTrue() {
        let ticket = Ticket(
            id: "local-1",
            identifier: "LOCAL-1",
            title: "Local Task",
            state: "Todo",
            source: .local,
            priority: 0,
            updatedAt: Date()
        )

        XCTAssertTrue(ticket.isLocal)
    }

    func test_isLocal_withLinearSource_returnsFalse() {
        let ticket = makeTicket()

        XCTAssertFalse(ticket.isLocal)
    }

    func test_url_withLocalSource_returnsNil() {
        let ticket = Ticket(
            id: "local-1",
            identifier: "LOCAL-1",
            title: "Local Task",
            state: "Todo",
            source: .local,
            priority: 0,
            updatedAt: Date()
        )

        XCTAssertNil(ticket.url)
    }

    func test_url_withLinearSource_returnsUrl() {
        let ticket = makeTicket()

        XCTAssertEqual(ticket.url, "https://linear.app/test")
    }
}
