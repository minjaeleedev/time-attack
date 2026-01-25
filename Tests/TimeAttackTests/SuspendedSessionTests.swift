import XCTest
@testable import TimeAttackCore

final class SuspendedSessionTests: XCTestCase {

    // MARK: - Initialization

    func test_init_setsPropertiesCorrectly() {
        let date = Date()
        let session = SuspendedSession(
            ticketId: "TICKET-123",
            remainingTime: 810,
            suspendedAt: date
        )

        XCTAssertEqual(session.ticketId, "TICKET-123")
        XCTAssertEqual(session.remainingTime, 810)
        XCTAssertEqual(session.suspendedAt, date)
    }

    func test_init_withVariousRemainingTimes() {
        let testCases: [(remainingTime: TimeInterval, description: String)] = [
            (0, "zero remaining"),
            (60, "1 minute remaining"),
            (3600, "1 hour remaining"),
            (86400, "1 day remaining"),
        ]

        for testCase in testCases {
            let session = SuspendedSession(
                ticketId: "test",
                remainingTime: testCase.remainingTime,
                suspendedAt: Date()
            )

            XCTAssertEqual(
                session.remainingTime,
                testCase.remainingTime,
                "Failed for: \(testCase.description)"
            )
        }
    }

    // MARK: - Equatable

    func test_equatable_sameSessions_areEqual() {
        let date = Date()
        let session1 = SuspendedSession(ticketId: "TICKET-1", remainingTime: 300, suspendedAt: date)
        let session2 = SuspendedSession(ticketId: "TICKET-1", remainingTime: 300, suspendedAt: date)

        XCTAssertEqual(session1, session2)
    }

    func test_equatable_differentTicketIds_areNotEqual() {
        let date = Date()
        let session1 = SuspendedSession(ticketId: "TICKET-1", remainingTime: 300, suspendedAt: date)
        let session2 = SuspendedSession(ticketId: "TICKET-2", remainingTime: 300, suspendedAt: date)

        XCTAssertNotEqual(session1, session2)
    }

    func test_equatable_differentRemainingTimes_areNotEqual() {
        let date = Date()
        let session1 = SuspendedSession(ticketId: "TICKET-1", remainingTime: 300, suspendedAt: date)
        let session2 = SuspendedSession(ticketId: "TICKET-1", remainingTime: 600, suspendedAt: date)

        XCTAssertNotEqual(session1, session2)
    }

    func test_equatable_differentDates_areNotEqual() {
        let date1 = Date()
        let date2 = date1.addingTimeInterval(60)
        let session1 = SuspendedSession(ticketId: "TICKET-1", remainingTime: 300, suspendedAt: date1)
        let session2 = SuspendedSession(ticketId: "TICKET-1", remainingTime: 300, suspendedAt: date2)

        XCTAssertNotEqual(session1, session2)
    }

    // MARK: - Codable

    func test_codable_encodesAndDecodesCorrectly() throws {
        let date = Date()
        let original = SuspendedSession(
            ticketId: "TICKET-123",
            remainingTime: 1234.5,
            suspendedAt: date
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SuspendedSession.self, from: data)

        XCTAssertEqual(decoded.ticketId, original.ticketId)
        XCTAssertEqual(decoded.remainingTime, original.remainingTime)
        XCTAssertEqual(
            decoded.suspendedAt.timeIntervalSince1970,
            original.suspendedAt.timeIntervalSince1970,
            accuracy: 1.0
        )
    }
}
