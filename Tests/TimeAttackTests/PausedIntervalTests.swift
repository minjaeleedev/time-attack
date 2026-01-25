import XCTest
@testable import TimeAttackCore

final class PausedIntervalTests: XCTestCase {

    // MARK: - Initialization

    func test_init_withStartOnly() {
        let start = Date()
        let interval = PausedInterval(start: start)

        XCTAssertEqual(interval.start, start)
        XCTAssertNil(interval.end)
    }

    func test_init_withStartAndEnd() {
        let start = Date()
        let end = start.addingTimeInterval(300)
        let interval = PausedInterval(start: start, end: end)

        XCTAssertEqual(interval.start, start)
        XCTAssertEqual(interval.end, end)
    }

    func test_init_withNilEnd() {
        let start = Date()
        let interval = PausedInterval(start: start, end: nil)

        XCTAssertEqual(interval.start, start)
        XCTAssertNil(interval.end)
    }

    // MARK: - Equatable

    func test_equatable_sameIntervals_areEqual() {
        let start = Date()
        let end = start.addingTimeInterval(60)
        let interval1 = PausedInterval(start: start, end: end)
        let interval2 = PausedInterval(start: start, end: end)

        XCTAssertEqual(interval1, interval2)
    }

    func test_equatable_bothNilEnds_areEqual() {
        let start = Date()
        let interval1 = PausedInterval(start: start, end: nil)
        let interval2 = PausedInterval(start: start, end: nil)

        XCTAssertEqual(interval1, interval2)
    }

    func test_equatable_differentStarts_areNotEqual() {
        let start1 = Date()
        let start2 = start1.addingTimeInterval(10)
        let interval1 = PausedInterval(start: start1, end: nil)
        let interval2 = PausedInterval(start: start2, end: nil)

        XCTAssertNotEqual(interval1, interval2)
    }

    func test_equatable_differentEnds_areNotEqual() {
        let start = Date()
        let end1 = start.addingTimeInterval(60)
        let end2 = start.addingTimeInterval(120)
        let interval1 = PausedInterval(start: start, end: end1)
        let interval2 = PausedInterval(start: start, end: end2)

        XCTAssertNotEqual(interval1, interval2)
    }

    func test_equatable_nilVsNonNilEnd_areNotEqual() {
        let start = Date()
        let end = start.addingTimeInterval(60)
        let interval1 = PausedInterval(start: start, end: nil)
        let interval2 = PausedInterval(start: start, end: end)

        XCTAssertNotEqual(interval1, interval2)
    }

    // MARK: - Codable

    func test_codable_withEnd_encodesAndDecodesCorrectly() throws {
        let start = Date()
        let end = start.addingTimeInterval(300)
        let original = PausedInterval(start: start, end: end)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PausedInterval.self, from: data)

        XCTAssertEqual(
            decoded.start.timeIntervalSince1970,
            original.start.timeIntervalSince1970,
            accuracy: 1.0
        )
        XCTAssertNotNil(decoded.end)
        XCTAssertEqual(
            decoded.end!.timeIntervalSince1970,
            original.end!.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func test_codable_withNilEnd_encodesAndDecodesCorrectly() throws {
        let start = Date()
        let original = PausedInterval(start: start, end: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PausedInterval.self, from: data)

        XCTAssertEqual(
            decoded.start.timeIntervalSince1970,
            original.start.timeIntervalSince1970,
            accuracy: 1.0
        )
        XCTAssertNil(decoded.end)
    }

    // MARK: - Duration Calculation (Example usage pattern)

    func test_duration_calculation_forCompletedInterval() {
        let testCases: [(duration: TimeInterval, description: String)] = [
            (0, "zero duration"),
            (60, "1 minute"),
            (300, "5 minutes"),
            (3600, "1 hour"),
        ]

        for testCase in testCases {
            let start = Date()
            let end = start.addingTimeInterval(testCase.duration)
            let interval = PausedInterval(start: start, end: end)

            let calculatedDuration = interval.end!.timeIntervalSince(interval.start)
            XCTAssertEqual(
                calculatedDuration,
                testCase.duration,
                accuracy: 0.001,
                "Failed for: \(testCase.description)"
            )
        }
    }
}
