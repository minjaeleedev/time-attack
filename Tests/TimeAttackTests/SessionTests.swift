import XCTest
@testable import TimeAttackCore

final class SessionTests: XCTestCase {

    // MARK: - totalPausedTime

    func test_totalPausedTime_withNoPauses_returnsZero() {
        let session = Session(ticketId: "test-ticket")

        XCTAssertEqual(session.totalPausedTime, 0)
    }

    func test_totalPausedTime_withCompletedPauses_returnsCorrectDuration() {
        let testCases: [(pauseDurations: [TimeInterval], expected: TimeInterval)] = [
            ([300], 300),                    // Single 5 minute pause
            ([60, 120], 180),                // Two pauses: 1 + 2 = 3 minutes
            ([30, 30, 30], 90),              // Three pauses: 30 * 3 = 90 seconds
            ([3600], 3600),                  // Single 1 hour pause
        ]

        for testCase in testCases {
            var pausedIntervals: [PausedInterval] = []
            var currentTime = Date()

            for duration in testCase.pauseDurations {
                let start = currentTime
                let end = start.addingTimeInterval(duration)
                pausedIntervals.append(PausedInterval(start: start, end: end))
                currentTime = end.addingTimeInterval(60) // Gap between pauses
            }

            let session = Session(ticketId: "test-ticket", pausedIntervals: pausedIntervals)

            XCTAssertEqual(
                session.totalPausedTime,
                testCase.expected,
                accuracy: 0.001,
                "Expected total paused time \(testCase.expected) for durations \(testCase.pauseDurations)"
            )
        }
    }

    func test_totalPausedTime_withActivePause_excludesActivePause() {
        let completedPauseStart = Date()
        let completedPauseEnd = completedPauseStart.addingTimeInterval(60)
        let completedPause = PausedInterval(start: completedPauseStart, end: completedPauseEnd)

        let activePauseStart = completedPauseEnd.addingTimeInterval(60)
        let activePause = PausedInterval(start: activePauseStart, end: nil)

        let session = Session(ticketId: "test-ticket", pausedIntervals: [completedPause, activePause])

        XCTAssertEqual(session.totalPausedTime, 60, accuracy: 0.001)
    }

    // MARK: - actualDuration

    func test_actualDuration_withEndTime_returnsCorrectDuration() {
        let start = Date()
        let end = start.addingTimeInterval(3600)
        let session = Session(ticketId: "test-ticket", startTime: start, endTime: end)

        XCTAssertNotNil(session.actualDuration)
        XCTAssertEqual(session.actualDuration!, 3600, accuracy: 0.001)
    }

    func test_actualDuration_withEndTimeAndPauses_subtractsPausedTime() {
        let start = Date()
        let end = start.addingTimeInterval(3600) // 1 hour total

        let pauseStart = start.addingTimeInterval(600) // 10 minutes in
        let pauseEnd = pauseStart.addingTimeInterval(600) // 10 minute pause
        let pause = PausedInterval(start: pauseStart, end: pauseEnd)

        let session = Session(ticketId: "test-ticket", startTime: start, endTime: end, pausedIntervals: [pause])

        XCTAssertNotNil(session.actualDuration)
        XCTAssertEqual(session.actualDuration!, 3000, accuracy: 0.001) // 60 - 10 = 50 minutes
    }

    func test_actualDuration_withoutEndTime_returnsNil() {
        let session = Session(ticketId: "test-ticket")

        XCTAssertNil(session.actualDuration)
    }

    // MARK: - isActive (Parameterized)

    func test_isActive_returnsExpectedValue() {
        let start = Date()
        let testCases: [(session: Session, expected: Bool)] = [
            (Session(ticketId: "test-ticket"), true),
            (Session(ticketId: "test-ticket", startTime: start, endTime: start.addingTimeInterval(100)), false),
        ]

        for testCase in testCases {
            XCTAssertEqual(
                testCase.session.isActive,
                testCase.expected,
                "Expected isActive to be \(testCase.expected)"
            )
        }
    }

    // MARK: - isPaused (Parameterized)

    func test_isPaused_returnsExpectedValue() {
        let start = Date()
        let completedPause = PausedInterval(start: start, end: start.addingTimeInterval(60))
        let activePause = PausedInterval(start: start.addingTimeInterval(120), end: nil)

        let testCases: [(description: String, session: Session, expected: Bool)] = [
            ("No pauses", Session(ticketId: "test"), false),
            ("Active pause only", Session(ticketId: "test", pausedIntervals: [activePause]), true),
            ("Completed pause only", Session(ticketId: "test", pausedIntervals: [completedPause]), false),
            ("Completed + active pause", Session(ticketId: "test", pausedIntervals: [completedPause, activePause]), true),
            ("Multiple completed pauses", Session(ticketId: "test", pausedIntervals: [completedPause, completedPause]), false),
        ]

        for testCase in testCases {
            XCTAssertEqual(
                testCase.session.isPaused,
                testCase.expected,
                "Expected isPaused to be \(testCase.expected) for: \(testCase.description)"
            )
        }
    }

    // MARK: - SessionMode (Parameterized)

    func test_sessionMode_work_properties() {
        let mode = SessionMode.work(ticketId: "test-ticket")

        XCTAssertTrue(mode.isWork)
        XCTAssertFalse(mode.isRest)
        XCTAssertEqual(mode.ticketId, "test-ticket")
        XCTAssertNil(mode.restDuration)
    }

    func test_sessionMode_rest_properties() {
        let mode = SessionMode.rest(duration: 300)

        XCTAssertFalse(mode.isWork)
        XCTAssertTrue(mode.isRest)
        XCTAssertNil(mode.ticketId)
        XCTAssertEqual(mode.restDuration, 300)
    }

    func test_session_defaultMode_isWork() {
        let session = Session(ticketId: "test-ticket")

        XCTAssertTrue(session.mode.isWork)
        XCTAssertEqual(session.mode.ticketId, "test-ticket")
    }

    func test_session_restSession_hasCorrectMode() {
        let session = Session.restSession(duration: 600)

        XCTAssertTrue(session.mode.isRest)
        XCTAssertEqual(session.mode.restDuration, 600)
        XCTAssertEqual(session.ticketId, "rest")
    }

    func test_session_withExplicitModes() {
        let testCases: [(mode: SessionMode, expectWork: Bool, expectRest: Bool)] = [
            (.work(ticketId: "test-ticket"), true, false),
            (.rest(duration: 900), false, true),
        ]

        for testCase in testCases {
            let ticketId = testCase.mode.isWork ? "test-ticket" : "rest"
            let session = Session(ticketId: ticketId, mode: testCase.mode)

            XCTAssertEqual(
                session.mode.isWork,
                testCase.expectWork,
                "Expected isWork to be \(testCase.expectWork)"
            )
            XCTAssertEqual(
                session.mode.isRest,
                testCase.expectRest,
                "Expected isRest to be \(testCase.expectRest)"
            )
        }
    }

    // MARK: - initialRemainingTime

    func test_session_initialRemainingTime() {
        let testCases: [(initialTime: TimeInterval?, expected: TimeInterval?)] = [
            (nil, nil),
            (810, 810),
            (3600, 3600),
            (0, 0),
        ]

        for testCase in testCases {
            let session = Session(ticketId: "test-ticket", initialRemainingTime: testCase.initialTime)

            XCTAssertEqual(
                session.initialRemainingTime,
                testCase.expected,
                "Expected initialRemainingTime to be \(String(describing: testCase.expected))"
            )
        }
    }

    func test_session_resumedSession_preservesInitialRemainingTime() {
        let session = Session(
            ticketId: "test-ticket",
            mode: .work(ticketId: "test-ticket"),
            initialRemainingTime: 810
        )

        XCTAssertNotNil(session.initialRemainingTime)
        XCTAssertEqual(session.initialRemainingTime!, 810, accuracy: 0.001)
        XCTAssertTrue(session.mode.isWork)
    }
}
