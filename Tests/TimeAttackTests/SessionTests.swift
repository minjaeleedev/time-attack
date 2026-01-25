import XCTest
@testable import TimeAttackCore

final class SessionTests: XCTestCase {

    // MARK: - totalPausedTime

    func test_totalPausedTime_withNoPauses_returnsZero() {
        // Given
        let session = Session(ticketId: "test-ticket")

        // When
        let result = session.totalPausedTime

        // Then
        XCTAssertEqual(result, 0)
    }

    func test_totalPausedTime_withCompletedPause_returnsCorrectDuration() {
        // Given
        let pauseStart = Date()
        let pauseEnd = pauseStart.addingTimeInterval(300) // 5 minutes
        let pause = PausedInterval(start: pauseStart, end: pauseEnd)
        let session = Session(ticketId: "test-ticket", pausedIntervals: [pause])

        // When
        let result = session.totalPausedTime

        // Then
        XCTAssertEqual(result, 300, accuracy: 0.001)
    }

    func test_totalPausedTime_withMultiplePauses_returnsTotalDuration() {
        // Given
        let pause1Start = Date()
        let pause1End = pause1Start.addingTimeInterval(60) // 1 minute
        let pause1 = PausedInterval(start: pause1Start, end: pause1End)

        let pause2Start = pause1End.addingTimeInterval(120) // 2 minutes after first pause
        let pause2End = pause2Start.addingTimeInterval(120) // 2 minutes
        let pause2 = PausedInterval(start: pause2Start, end: pause2End)

        let session = Session(ticketId: "test-ticket", pausedIntervals: [pause1, pause2])

        // When
        let result = session.totalPausedTime

        // Then
        XCTAssertEqual(result, 180, accuracy: 0.001) // 1 + 2 = 3 minutes
    }

    func test_totalPausedTime_withActivePause_excludesActivePause() {
        // Given
        let completedPauseStart = Date()
        let completedPauseEnd = completedPauseStart.addingTimeInterval(60)
        let completedPause = PausedInterval(start: completedPauseStart, end: completedPauseEnd)

        let activePauseStart = completedPauseEnd.addingTimeInterval(60)
        let activePause = PausedInterval(start: activePauseStart, end: nil)

        let session = Session(ticketId: "test-ticket", pausedIntervals: [completedPause, activePause])

        // When
        let result = session.totalPausedTime

        // Then
        XCTAssertEqual(result, 60, accuracy: 0.001) // Only completed pause
    }

    // MARK: - actualDuration

    func test_actualDuration_withEndTime_returnsCorrectDuration() {
        // Given
        let start = Date()
        let end = start.addingTimeInterval(3600) // 1 hour
        let session = Session(ticketId: "test-ticket", startTime: start, endTime: end)

        // When
        let result = session.actualDuration

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 3600, accuracy: 0.001)
    }

    func test_actualDuration_withEndTimeAndPauses_subtractsPausedTime() {
        // Given
        let start = Date()
        let end = start.addingTimeInterval(3600) // 1 hour total

        let pauseStart = start.addingTimeInterval(600) // 10 minutes in
        let pauseEnd = pauseStart.addingTimeInterval(600) // 10 minute pause
        let pause = PausedInterval(start: pauseStart, end: pauseEnd)

        let session = Session(ticketId: "test-ticket", startTime: start, endTime: end, pausedIntervals: [pause])

        // When
        let result = session.actualDuration

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 3000, accuracy: 0.001) // 60 - 10 = 50 minutes
    }

    func test_actualDuration_withoutEndTime_returnsNil() {
        // Given
        let session = Session(ticketId: "test-ticket")

        // When
        let result = session.actualDuration

        // Then
        XCTAssertNil(result)
    }

    // MARK: - isActive

    func test_isActive_withoutEndTime_returnsTrue() {
        // Given
        let session = Session(ticketId: "test-ticket")

        // When
        let result = session.isActive

        // Then
        XCTAssertTrue(result)
    }

    func test_isActive_withEndTime_returnsFalse() {
        // Given
        let start = Date()
        let end = start.addingTimeInterval(100)
        let session = Session(ticketId: "test-ticket", startTime: start, endTime: end)

        // When
        let result = session.isActive

        // Then
        XCTAssertFalse(result)
    }

    // MARK: - isPaused

    func test_isPaused_withNoPause_returnsFalse() {
        // Given
        let session = Session(ticketId: "test-ticket")

        // When
        let result = session.isPaused

        // Then
        XCTAssertFalse(result)
    }

    func test_isPaused_withActivePause_returnsTrue() {
        // Given
        let activePause = PausedInterval(start: Date(), end: nil)
        let session = Session(ticketId: "test-ticket", pausedIntervals: [activePause])

        // When
        let result = session.isPaused

        // Then
        XCTAssertTrue(result)
    }

    func test_isPaused_withCompletedPause_returnsFalse() {
        // Given
        let start = Date()
        let completedPause = PausedInterval(start: start, end: start.addingTimeInterval(60))
        let session = Session(ticketId: "test-ticket", pausedIntervals: [completedPause])

        // When
        let result = session.isPaused

        // Then
        XCTAssertFalse(result)
    }

    func test_isPaused_withMultiplePausesLastActive_returnsTrue() {
        // Given
        let start = Date()
        let completedPause = PausedInterval(start: start, end: start.addingTimeInterval(60))
        let activePause = PausedInterval(start: start.addingTimeInterval(120), end: nil)
        let session = Session(ticketId: "test-ticket", pausedIntervals: [completedPause, activePause])

        // When
        let result = session.isPaused

        // Then
        XCTAssertTrue(result)
    }

    func test_isPaused_withMultiplePausesAllCompleted_returnsFalse() {
        // Given
        let start = Date()
        let pause1 = PausedInterval(start: start, end: start.addingTimeInterval(60))
        let pause2 = PausedInterval(start: start.addingTimeInterval(120), end: start.addingTimeInterval(180))
        let session = Session(ticketId: "test-ticket", pausedIntervals: [pause1, pause2])

        // When
        let result = session.isPaused

        // Then
        XCTAssertFalse(result)
    }

    // MARK: - SessionMode

    func test_sessionMode_work_isWorkTrue() {
        // Given
        let mode = SessionMode.work(ticketId: "test-ticket")

        // Then
        XCTAssertTrue(mode.isWork)
        XCTAssertFalse(mode.isRest)
        XCTAssertEqual(mode.ticketId, "test-ticket")
        XCTAssertNil(mode.restDuration)
    }

    func test_sessionMode_rest_isRestTrue() {
        // Given
        let mode = SessionMode.rest(duration: 300)

        // Then
        XCTAssertFalse(mode.isWork)
        XCTAssertTrue(mode.isRest)
        XCTAssertNil(mode.ticketId)
        XCTAssertEqual(mode.restDuration, 300)
    }

    func test_session_defaultMode_isWork() {
        // Given
        let session = Session(ticketId: "test-ticket")

        // Then
        XCTAssertTrue(session.mode.isWork)
        XCTAssertEqual(session.mode.ticketId, "test-ticket")
    }

    func test_session_restSession_hasCorrectMode() {
        // Given
        let session = Session.restSession(duration: 600)

        // Then
        XCTAssertTrue(session.mode.isRest)
        XCTAssertEqual(session.mode.restDuration, 600)
        XCTAssertEqual(session.ticketId, "rest")
    }

    func test_session_withExplicitWorkMode() {
        // Given
        let session = Session(
            ticketId: "test-ticket",
            mode: .work(ticketId: "test-ticket")
        )

        // Then
        XCTAssertTrue(session.mode.isWork)
        XCTAssertEqual(session.mode.ticketId, "test-ticket")
    }

    func test_session_withExplicitRestMode() {
        // Given
        let session = Session(
            ticketId: "rest",
            mode: .rest(duration: 900)
        )

        // Then
        XCTAssertTrue(session.mode.isRest)
        XCTAssertEqual(session.mode.restDuration, 900)
    }

    // MARK: - initialRemainingTime

    func test_session_withoutInitialRemainingTime_returnsNil() {
        // Given
        let session = Session(ticketId: "test-ticket")

        // Then
        XCTAssertNil(session.initialRemainingTime)
    }

    func test_session_withInitialRemainingTime_returnsValue() {
        // Given
        let session = Session(
            ticketId: "test-ticket",
            initialRemainingTime: 810  // 13:30 remaining
        )

        // Then
        XCTAssertEqual(session.initialRemainingTime, 810)
    }

    func test_session_resumedSession_preservesInitialRemainingTime() {
        // Given: Session resumed with 13:30 (810 seconds) remaining
        let session = Session(
            ticketId: "test-ticket",
            mode: .work(ticketId: "test-ticket"),
            initialRemainingTime: 810
        )

        // Then
        XCTAssertNotNil(session.initialRemainingTime)
        XCTAssertEqual(session.initialRemainingTime!, 810, accuracy: 0.001)
        XCTAssertTrue(session.mode.isWork)
    }
}
