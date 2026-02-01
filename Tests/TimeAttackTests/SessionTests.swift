import XCTest
@testable import TimeAttackCore

final class SessionTests: XCTestCase {

    // MARK: - Session Basic Tests

    func test_session_isActive_whenNoEndTime_returnsTrue() {
        let session = Session()

        XCTAssertTrue(session.isActive)
    }

    func test_session_isActive_whenHasEndTime_returnsFalse() {
        let session = Session().withEndTime(Date())

        XCTAssertFalse(session.isActive)
    }

    func test_session_activeTask_returnsFirstTaskWithNoEndTime() {
        let sessionId = UUID()
        let completedTask = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-1"),
            startTime: Date().addingTimeInterval(-100),
            endTime: Date().addingTimeInterval(-50)
        )
        let activeTask = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-2")
        )

        let session = Session(tasks: [completedTask, activeTask])

        XCTAssertEqual(session.activeTask?.id, activeTask.id)
    }

    func test_session_activeTask_whenAllTasksComplete_returnsNil() {
        let sessionId = UUID()
        let completedTask = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-1"),
            endTime: Date()
        )

        let session = Session(tasks: [completedTask])

        XCTAssertNil(session.activeTask)
    }

    // MARK: - Session Time Calculations

    func test_session_totalWorkTime_sumsOnlyWorkTasks() {
        let sessionId = UUID()
        let now = Date()

        let workTask1 = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-1"),
            startTime: now.addingTimeInterval(-300),
            endTime: now.addingTimeInterval(-200)
        )
        let restTask = SessionTask(
            sessionId: sessionId,
            type: .rest(duration: 300),
            startTime: now.addingTimeInterval(-200),
            endTime: now.addingTimeInterval(-100)
        )
        let workTask2 = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-2"),
            startTime: now.addingTimeInterval(-100),
            endTime: now
        )

        let session = Session(tasks: [workTask1, restTask, workTask2])

        XCTAssertEqual(session.totalWorkTime, 200, accuracy: 0.001)
    }

    func test_session_totalRestTime_sumsOnlyRestTasks() {
        let sessionId = UUID()
        let now = Date()

        let workTask = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-1"),
            startTime: now.addingTimeInterval(-300),
            endTime: now.addingTimeInterval(-200)
        )
        let restTask = SessionTask(
            sessionId: sessionId,
            type: .rest(duration: 300),
            startTime: now.addingTimeInterval(-200),
            endTime: now
        )

        let session = Session(tasks: [workTask, restTask])

        XCTAssertEqual(session.totalRestTime, 200, accuracy: 0.001)
    }

    func test_session_totalOverheadTime_sumsDecidingAndTransitioning() {
        let sessionId = UUID()
        let now = Date()

        let decidingTask = SessionTask(
            sessionId: sessionId,
            type: .deciding,
            startTime: now.addingTimeInterval(-300),
            endTime: now.addingTimeInterval(-280)
        )
        let transitionTask = SessionTask(
            sessionId: sessionId,
            type: .transitioning(fromTicketId: "ticket-1"),
            startTime: now.addingTimeInterval(-150),
            endTime: now.addingTimeInterval(-140)
        )
        let workTask = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-1"),
            startTime: now.addingTimeInterval(-280),
            endTime: now.addingTimeInterval(-150)
        )

        let session = Session(tasks: [decidingTask, workTask, transitionTask])

        XCTAssertEqual(session.totalOverheadTime, 30, accuracy: 0.001) // 20 + 10
    }

    func test_session_uniqueTicketIds_returnsDistinctTicketIds() {
        let sessionId = UUID()
        let now = Date()

        let work1 = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-1"),
            startTime: now.addingTimeInterval(-300),
            endTime: now.addingTimeInterval(-200)
        )
        let work2 = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-2"),
            startTime: now.addingTimeInterval(-200),
            endTime: now.addingTimeInterval(-100)
        )
        let work3 = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-1"),
            startTime: now.addingTimeInterval(-100),
            endTime: now
        )

        let session = Session(tasks: [work1, work2, work3])
        let uniqueIds = session.uniqueTicketIds

        XCTAssertEqual(uniqueIds.count, 2)
        XCTAssertTrue(uniqueIds.contains("ticket-1"))
        XCTAssertTrue(uniqueIds.contains("ticket-2"))
    }

    func test_session_workTimeForTicket_returnsTotalTimeForSpecificTicket() {
        let sessionId = UUID()
        let now = Date()

        let work1 = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-1"),
            startTime: now.addingTimeInterval(-300),
            endTime: now.addingTimeInterval(-200)
        )
        let work2 = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-2"),
            startTime: now.addingTimeInterval(-200),
            endTime: now.addingTimeInterval(-100)
        )
        let work3 = SessionTask(
            sessionId: sessionId,
            type: .work(ticketId: "ticket-1"),
            startTime: now.addingTimeInterval(-100),
            endTime: now
        )

        let session = Session(tasks: [work1, work2, work3])

        XCTAssertEqual(session.workTimeForTicket("ticket-1"), 200, accuracy: 0.001)
        XCTAssertEqual(session.workTimeForTicket("ticket-2"), 100, accuracy: 0.001)
    }

    // MARK: - Session Mutation Tests

    func test_session_appendingTask_createsNewSessionWithTask() {
        let session = Session()
        let task = SessionTask(sessionId: session.id, type: .deciding)

        let newSession = session.appendingTask(task)

        XCTAssertEqual(newSession.tasks.count, 1)
        XCTAssertEqual(session.tasks.count, 0)
    }

    func test_session_updatingTask_replacesExistingTask() {
        let session = Session()
        let task = SessionTask(sessionId: session.id, type: .deciding)
        let sessionWithTask = session.appendingTask(task)
        let updatedTask = task.withEndTime(Date())

        let newSession = sessionWithTask.updatingTask(updatedTask)

        XCTAssertNotNil(newSession.tasks.first?.endTime)
    }
}

// MARK: - SessionTask Tests

final class SessionTaskTests: XCTestCase {

    func test_task_totalPausedTime_withNoPauses_returnsZero() {
        let task = SessionTask(sessionId: UUID(), type: .work(ticketId: "test"))

        XCTAssertEqual(task.totalPausedTime, 0)
    }

    func test_task_totalPausedTime_withCompletedPauses_returnsCorrectDuration() {
        let start = Date()
        let pauseStart = start.addingTimeInterval(60)
        let pauseEnd = pauseStart.addingTimeInterval(30)
        let pause = PausedInterval(start: pauseStart, end: pauseEnd)

        let task = SessionTask(
            sessionId: UUID(),
            type: .work(ticketId: "test"),
            pausedIntervals: [pause]
        )

        XCTAssertEqual(task.totalPausedTime, 30, accuracy: 0.001)
    }

    func test_task_totalPausedTime_excludesActivePause() {
        let start = Date()
        let completedPause = PausedInterval(start: start, end: start.addingTimeInterval(30))
        let activePause = PausedInterval(start: start.addingTimeInterval(60), end: nil)

        let task = SessionTask(
            sessionId: UUID(),
            type: .work(ticketId: "test"),
            pausedIntervals: [completedPause, activePause]
        )

        XCTAssertEqual(task.totalPausedTime, 30, accuracy: 0.001)
    }

    func test_task_actualDuration_subtractsPausedTime() {
        let start = Date()
        let end = start.addingTimeInterval(100)
        let pauseStart = start.addingTimeInterval(20)
        let pauseEnd = pauseStart.addingTimeInterval(30)
        let pause = PausedInterval(start: pauseStart, end: pauseEnd)

        let task = SessionTask(
            sessionId: UUID(),
            type: .work(ticketId: "test"),
            startTime: start,
            endTime: end,
            pausedIntervals: [pause]
        )

        XCTAssertEqual(task.actualDuration, 70, accuracy: 0.001)
    }

    func test_task_isActive_whenNoEndTime_returnsTrue() {
        let task = SessionTask(sessionId: UUID(), type: .work(ticketId: "test"))

        XCTAssertTrue(task.isActive)
    }

    func test_task_isActive_whenHasEndTime_returnsFalse() {
        let task = SessionTask(
            sessionId: UUID(),
            type: .work(ticketId: "test"),
            endTime: Date()
        )

        XCTAssertFalse(task.isActive)
    }

    func test_task_isPaused_whenLastPauseHasNoEnd_returnsTrue() {
        let activePause = PausedInterval(start: Date(), end: nil)
        let task = SessionTask(
            sessionId: UUID(),
            type: .work(ticketId: "test"),
            pausedIntervals: [activePause]
        )

        XCTAssertTrue(task.isPaused)
    }

    func test_task_isPaused_whenAllPausesComplete_returnsFalse() {
        let completedPause = PausedInterval(start: Date(), end: Date())
        let task = SessionTask(
            sessionId: UUID(),
            type: .work(ticketId: "test"),
            pausedIntervals: [completedPause]
        )

        XCTAssertFalse(task.isPaused)
    }
}

// MARK: - TaskType Tests

final class TaskTypeTests: XCTestCase {

    func test_taskType_work_properties() {
        let type = TaskType.work(ticketId: "test-ticket")

        XCTAssertTrue(type.isWork)
        XCTAssertFalse(type.isRest)
        XCTAssertFalse(type.isDeciding)
        XCTAssertFalse(type.isTransitioning)
        XCTAssertEqual(type.ticketId, "test-ticket")
        XCTAssertNil(type.restDuration)
        XCTAssertNil(type.fromTicketId)
    }

    func test_taskType_rest_properties() {
        let type = TaskType.rest(duration: 300)

        XCTAssertFalse(type.isWork)
        XCTAssertTrue(type.isRest)
        XCTAssertFalse(type.isDeciding)
        XCTAssertFalse(type.isTransitioning)
        XCTAssertNil(type.ticketId)
        XCTAssertEqual(type.restDuration, 300)
        XCTAssertNil(type.fromTicketId)
    }

    func test_taskType_deciding_properties() {
        let type = TaskType.deciding

        XCTAssertFalse(type.isWork)
        XCTAssertFalse(type.isRest)
        XCTAssertTrue(type.isDeciding)
        XCTAssertFalse(type.isTransitioning)
        XCTAssertNil(type.ticketId)
        XCTAssertNil(type.restDuration)
        XCTAssertNil(type.fromTicketId)
    }

    func test_taskType_transitioning_properties() {
        let type = TaskType.transitioning(fromTicketId: "old-ticket")

        XCTAssertFalse(type.isWork)
        XCTAssertFalse(type.isRest)
        XCTAssertFalse(type.isDeciding)
        XCTAssertTrue(type.isTransitioning)
        XCTAssertNil(type.ticketId)
        XCTAssertNil(type.restDuration)
        XCTAssertEqual(type.fromTicketId, "old-ticket")
    }

    func test_taskType_transitioning_withNilFromTicketId() {
        let type = TaskType.transitioning(fromTicketId: nil)

        XCTAssertTrue(type.isTransitioning)
        XCTAssertNil(type.fromTicketId)
    }

    func test_taskType_displayName() {
        XCTAssertEqual(TaskType.work(ticketId: "test").displayName, "작업")
        XCTAssertEqual(TaskType.rest(duration: 300).displayName, "휴식")
        XCTAssertEqual(TaskType.deciding.displayName, "결정 중")
        XCTAssertEqual(TaskType.transitioning(fromTicketId: nil).displayName, "전환 중")
    }
}

