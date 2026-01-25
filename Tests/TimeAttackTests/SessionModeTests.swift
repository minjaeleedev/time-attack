import XCTest
@testable import TimeAttackCore

final class SessionModeTests: XCTestCase {

    // MARK: - isWork / isRest (Parameterized)

    func test_isWork_isRest_returnsExpectedValues() {
        let testCases: [(mode: SessionMode, isWork: Bool, isRest: Bool)] = [
            (.work(ticketId: "TICKET-1"), true, false),
            (.work(ticketId: ""), true, false),
            (.rest(duration: 300), false, true),
            (.rest(duration: 0), false, true),
        ]

        for testCase in testCases {
            XCTAssertEqual(
                testCase.mode.isWork,
                testCase.isWork,
                "Expected isWork=\(testCase.isWork) for \(testCase.mode)"
            )
            XCTAssertEqual(
                testCase.mode.isRest,
                testCase.isRest,
                "Expected isRest=\(testCase.isRest) for \(testCase.mode)"
            )
        }
    }

    // MARK: - ticketId

    func test_ticketId_forWorkMode_returnsTicketId() {
        let testCases = ["TICKET-1", "TEST-123", "ABC", ""]

        for ticketId in testCases {
            let mode = SessionMode.work(ticketId: ticketId)
            XCTAssertEqual(mode.ticketId, ticketId)
        }
    }

    func test_ticketId_forRestMode_returnsNil() {
        let testCases: [TimeInterval] = [0, 60, 300, 3600]

        for duration in testCases {
            let mode = SessionMode.rest(duration: duration)
            XCTAssertNil(mode.ticketId)
        }
    }

    // MARK: - restDuration

    func test_restDuration_forRestMode_returnsDuration() {
        let testCases: [TimeInterval] = [0, 60, 300, 600, 3600]

        for duration in testCases {
            let mode = SessionMode.rest(duration: duration)
            XCTAssertEqual(mode.restDuration, duration)
        }
    }

    func test_restDuration_forWorkMode_returnsNil() {
        let testCases = ["TICKET-1", "TEST-123", ""]

        for ticketId in testCases {
            let mode = SessionMode.work(ticketId: ticketId)
            XCTAssertNil(mode.restDuration)
        }
    }

    // MARK: - Equatable

    func test_equatable_sameWorkModes_areEqual() {
        let mode1 = SessionMode.work(ticketId: "TICKET-1")
        let mode2 = SessionMode.work(ticketId: "TICKET-1")

        XCTAssertEqual(mode1, mode2)
    }

    func test_equatable_differentWorkModes_areNotEqual() {
        let mode1 = SessionMode.work(ticketId: "TICKET-1")
        let mode2 = SessionMode.work(ticketId: "TICKET-2")

        XCTAssertNotEqual(mode1, mode2)
    }

    func test_equatable_sameRestModes_areEqual() {
        let mode1 = SessionMode.rest(duration: 300)
        let mode2 = SessionMode.rest(duration: 300)

        XCTAssertEqual(mode1, mode2)
    }

    func test_equatable_differentRestModes_areNotEqual() {
        let mode1 = SessionMode.rest(duration: 300)
        let mode2 = SessionMode.rest(duration: 600)

        XCTAssertNotEqual(mode1, mode2)
    }

    func test_equatable_workVsRest_areNotEqual() {
        let workMode = SessionMode.work(ticketId: "TICKET-1")
        let restMode = SessionMode.rest(duration: 300)

        XCTAssertNotEqual(workMode, restMode)
    }

    // MARK: - Codable

    func test_codable_workMode_encodesAndDecodesCorrectly() throws {
        let original = SessionMode.work(ticketId: "TICKET-123")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SessionMode.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertTrue(decoded.isWork)
        XCTAssertEqual(decoded.ticketId, "TICKET-123")
    }

    func test_codable_restMode_encodesAndDecodesCorrectly() throws {
        let original = SessionMode.rest(duration: 900)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SessionMode.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertTrue(decoded.isRest)
        XCTAssertEqual(decoded.restDuration, 900)
    }
}
