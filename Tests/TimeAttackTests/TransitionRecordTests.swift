import XCTest
@testable import TimeAttackCore

final class TransitionRecordTests: XCTestCase {

    // MARK: - Initialization

    func test_init_withAllParameters() {
        let id = UUID()
        let date = Date()
        let record = TransitionRecord(
            id: id,
            date: date,
            duration: 45.5,
            fromTicketId: "TICKET-123"
        )

        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.date, date)
        XCTAssertEqual(record.duration, 45.5)
        XCTAssertEqual(record.fromTicketId, "TICKET-123")
    }

    func test_init_withDefaultParameters() {
        let record = TransitionRecord(duration: 30.0, fromTicketId: nil)

        XCTAssertNotNil(record.id)
        XCTAssertNotNil(record.date)
        XCTAssertEqual(record.duration, 30.0)
        XCTAssertNil(record.fromTicketId)
    }

    func test_init_withNilFromTicketId() {
        let record = TransitionRecord(duration: 60, fromTicketId: nil)

        XCTAssertNil(record.fromTicketId)
    }

    func test_init_withVariousDurations() {
        let testCases: [(duration: TimeInterval, description: String)] = [
            (0, "zero duration"),
            (0.5, "half second"),
            (10, "10 seconds"),
            (60, "1 minute"),
            (3600, "1 hour"),
        ]

        for testCase in testCases {
            let record = TransitionRecord(duration: testCase.duration, fromTicketId: nil)

            XCTAssertEqual(
                record.duration,
                testCase.duration,
                "Failed for: \(testCase.description)"
            )
        }
    }

    // MARK: - Identifiable

    func test_identifiable_eachRecordHasUniqueId() {
        let record1 = TransitionRecord(duration: 10, fromTicketId: nil)
        let record2 = TransitionRecord(duration: 10, fromTicketId: nil)

        XCTAssertNotEqual(record1.id, record2.id)
    }

    // MARK: - Equatable

    func test_equatable_sameRecords_areEqual() {
        let id = UUID()
        let date = Date()
        let record1 = TransitionRecord(id: id, date: date, duration: 30, fromTicketId: "T-1")
        let record2 = TransitionRecord(id: id, date: date, duration: 30, fromTicketId: "T-1")

        XCTAssertEqual(record1, record2)
    }

    func test_equatable_differentIds_areNotEqual() {
        let date = Date()
        let record1 = TransitionRecord(id: UUID(), date: date, duration: 30, fromTicketId: "T-1")
        let record2 = TransitionRecord(id: UUID(), date: date, duration: 30, fromTicketId: "T-1")

        XCTAssertNotEqual(record1, record2)
    }

    func test_equatable_differentDurations_areNotEqual() {
        let id = UUID()
        let date = Date()
        let record1 = TransitionRecord(id: id, date: date, duration: 30, fromTicketId: nil)
        let record2 = TransitionRecord(id: id, date: date, duration: 60, fromTicketId: nil)

        XCTAssertNotEqual(record1, record2)
    }

    func test_equatable_differentFromTicketIds_areNotEqual() {
        let id = UUID()
        let date = Date()
        let record1 = TransitionRecord(id: id, date: date, duration: 30, fromTicketId: "T-1")
        let record2 = TransitionRecord(id: id, date: date, duration: 30, fromTicketId: "T-2")

        XCTAssertNotEqual(record1, record2)
    }

    func test_equatable_nilVsNonNilFromTicketId_areNotEqual() {
        let id = UUID()
        let date = Date()
        let record1 = TransitionRecord(id: id, date: date, duration: 30, fromTicketId: nil)
        let record2 = TransitionRecord(id: id, date: date, duration: 30, fromTicketId: "T-1")

        XCTAssertNotEqual(record1, record2)
    }

    // MARK: - Codable

    func test_codable_encodesAndDecodesCorrectly() throws {
        let id = UUID()
        let date = Date()
        let original = TransitionRecord(
            id: id,
            date: date,
            duration: 123.45,
            fromTicketId: "TICKET-456"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TransitionRecord.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.duration, original.duration)
        XCTAssertEqual(decoded.fromTicketId, original.fromTicketId)
        XCTAssertEqual(
            decoded.date.timeIntervalSince1970,
            original.date.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func test_codable_withNilFromTicketId_encodesAndDecodesCorrectly() throws {
        let original = TransitionRecord(duration: 60, fromTicketId: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TransitionRecord.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.duration, original.duration)
        XCTAssertNil(decoded.fromTicketId)
    }
}
