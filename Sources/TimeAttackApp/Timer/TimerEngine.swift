import Foundation
import TimeAttackCore
import UserNotifications

@MainActor
final class TimerEngine: ObservableObject {
    static let shared = TimerEngine()

    private weak var appState: AppState?
    private weak var taskManager: TaskManager?

    private init() {
        requestNotificationPermission()
    }

    func configure(appState: AppState, taskManager: TaskManager) {
        self.appState = appState
        self.taskManager = taskManager
        appState.sessions = LocalStorage.shared.loadSessions()
        appState.suspendedSessions = LocalStorage.shared.loadSuspendedSessions()
        appState.transitionRecords = LocalStorage.shared.loadTransitionRecords()
    }

    // MARK: - Session Lifecycle

    func startSession() {
        guard let appState = appState else { return }
        guard appState.currentSession == nil else { return }

        let session = Session()
        let decidingTask = SessionTask(
            sessionId: session.id,
            type: .deciding
        )

        let sessionWithTask = session.appendingTask(decidingTask)
        appState.currentSession = sessionWithTask
        appState.sessions.append(sessionWithTask)
        saveSessions()

        appState.showingTaskSelection = true
    }

    func endSession() {
        guard let appState = appState,
            var session = appState.currentSession
        else { return }

        endActiveTask()

        session = appState.currentSession ?? session
        let completedSession = session.withEndTime(Date())

        if let index = appState.sessions.firstIndex(where: { $0.id == session.id }) {
            appState.sessions[index] = completedSession
        }

        appState.completedSession = completedSession
        appState.currentSession = nil
        saveSessions()

        cancelPendingNotifications()
        appState.showingSessionReport = true
    }

    // MARK: - Task Lifecycle

    func startTask(type: TaskType, initialRemainingTime: TimeInterval? = nil) {
        guard let appState = appState,
            var session = appState.currentSession
        else { return }

        endActiveTask()

        session = appState.currentSession ?? session

        let task = SessionTask(
            sessionId: session.id,
            type: type,
            initialRemainingTime: initialRemainingTime
        )

        session = session.appendingTask(task)
        appState.currentSession = session

        if let index = appState.sessions.firstIndex(where: { $0.id == session.id }) {
            appState.sessions[index] = session
        }

        saveSessions()

        if case .work(let ticketId) = type {
            autoTransitionToInProgress(ticketId: ticketId)
        } else if case .rest(let duration) = type {
            scheduleRestEndNotification(duration: duration)
        }
    }

    func endActiveTask() {
        guard let appState = appState,
            var session = appState.currentSession,
            var task = session.activeTask
        else { return }

        if task.isPaused, !task.pausedIntervals.isEmpty {
            var intervals = task.pausedIntervals
            let lastIndex = intervals.count - 1
            intervals[lastIndex] = intervals[lastIndex].withEnd(Date())
            task = task.withPausedIntervals(intervals)
        }

        task = task.withEndTime(Date())
        session = session.updatingTask(task)
        appState.currentSession = session

        if let index = appState.sessions.firstIndex(where: { $0.id == session.id }) {
            appState.sessions[index] = session
        }

        saveSessions()
        cancelPendingNotifications()
    }

    func startTransitionTask(fromTicketId: String?) {
        guard let appState = appState,
            appState.currentSession != nil
        else { return }

        startTask(type: .transitioning(fromTicketId: fromTicketId))
        appState.showingTaskSwitch = true
    }

    // MARK: - Work Session (Convenience)

    func startWorkSession(ticketId: String) {
        startTask(type: .work(ticketId: ticketId))
    }

    func startWorkTask(ticketId: String) {
        if appState?.currentSession == nil {
            startSession()
            appState?.showingTaskSelection = false
        }

        if let suspended = appState?.suspendedSessions[ticketId] {
            startTask(
                type: .work(ticketId: ticketId),
                initialRemainingTime: suspended.remainingTime
            )
            appState?.suspendedSessions.removeValue(forKey: ticketId)
            saveSuspendedSessions()
        } else {
            startTask(type: .work(ticketId: ticketId))
        }
    }

    // MARK: - Rest Session (Convenience)

    func startRestSession(duration: TimeInterval) {
        if appState?.currentSession == nil {
            startSession()
            appState?.showingTaskSelection = false
        }

        startTask(type: .rest(duration: duration))
    }

    func switchToRest(duration: TimeInterval) {
        startRestSession(duration: duration)
    }

    func switchToWork(ticketId: String) {
        startWorkTask(ticketId: ticketId)
    }

    // MARK: - Convenience (Suspend + Transition)

    func suspendAndTransition() {
        guard let appState = appState,
            let task = appState.activeTask
        else { return }

        if let ticketId = task.type.ticketId {
            let elapsed = Date().timeIntervalSince(task.startTime) - task.totalPausedTime
            let ticket = taskManager?.tasks.first(where: { $0.id == ticketId })
            let estimate = ticket?.localEstimate ?? 0
            let remaining = max(0, (task.initialRemainingTime ?? estimate) - elapsed)
            suspendCurrentTask(remainingTime: remaining)
            startTransitionTask(fromTicketId: ticketId)
        } else if task.type.isRest {
            startTransitionTask(fromTicketId: nil)
        }
    }

    func suspendAndSwitchTo(ticketId: String) {
        guard let appState = appState,
            let task = appState.activeTask
        else { return }

        if let currentTicketId = task.type.ticketId {
            let elapsed = Date().timeIntervalSince(task.startTime) - task.totalPausedTime
            let ticket = taskManager?.tasks.first(where: { $0.id == currentTicketId })
            let estimate = ticket?.localEstimate ?? 0
            let remaining = max(0, (task.initialRemainingTime ?? estimate) - elapsed)
            suspendCurrentTask(remainingTime: remaining)
        }

        startWorkTask(ticketId: ticketId)
    }

    // MARK: - Suspend/Resume

    func suspendCurrentTask(remainingTime: TimeInterval) {
        guard let appState = appState,
            let task = appState.activeTask,
            let ticketId = task.type.ticketId
        else { return }

        let suspended = SuspendedSession(
            ticketId: ticketId,
            remainingTime: remainingTime,
            suspendedAt: Date()
        )
        appState.suspendedSessions[ticketId] = suspended
        saveSuspendedSessions()
    }

    // MARK: - Pause/Resume

    func togglePause() {
        guard let appState = appState,
            var session = appState.currentSession,
            var task = session.activeTask
        else { return }

        var intervals = task.pausedIntervals
        if task.isPaused, !intervals.isEmpty {
            let lastIndex = intervals.count - 1
            intervals[lastIndex] = intervals[lastIndex].withEnd(Date())
        } else {
            intervals.append(PausedInterval(start: Date(), end: nil))
        }

        task = task.withPausedIntervals(intervals)
        session = session.updatingTask(task)
        appState.currentSession = session

        if let index = appState.sessions.firstIndex(where: { $0.id == session.id }) {
            appState.sessions[index] = session
        }

        saveSessions()
    }

    // MARK: - Legacy Support (for backward compatibility)

    func stopSession() {
        endSession()
    }

    func suspendCurrentSession(remainingTime: TimeInterval) {
        suspendCurrentTask(remainingTime: remainingTime)
        endActiveTask()
    }

    func resumeWorkSession(ticketId: String) {
        startWorkTask(ticketId: ticketId)
    }

    // MARK: - Persistence

    private func saveSessions() {
        guard let appState = appState else { return }
        LocalStorage.shared.saveSessions(appState.sessions)
    }

    private func saveSuspendedSessions() {
        guard let appState = appState else { return }
        LocalStorage.shared.saveSuspendedSessions(appState.suspendedSessions)
    }

    func recordTransitionTime(duration: TimeInterval, fromTicketId: String?) {
        guard let appState = appState, duration > 0 else { return }

        let record = TransitionRecord(duration: duration, fromTicketId: fromTicketId)
        appState.transitionRecords.append(record)
        LocalStorage.shared.saveTransitionRecords(appState.transitionRecords)
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
        }
    }

    private func scheduleRestEndNotification(duration: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "휴식 종료"
        content.body = "휴식 시간이 끝났습니다. 작업을 시작할 준비가 되셨나요?"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(
            identifier: "rest-end", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelPendingNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "rest-end"
        ])
    }

    // MARK: - Auto State Transition

    private func autoTransitionToInProgress(ticketId: String) {
        guard let appState = appState,
            let taskManager = taskManager
        else { return }

        guard let ticket = taskManager.tasks.first(where: { $0.id == ticketId }) else { return }

        let currentStateType = appState.workflowStatesForCurrentTeam()
            .first { $0.name == ticket.state }?.type

        guard currentStateType != "started" && currentStateType != "completed" else {
            return
        }

        guard let inProgressState = appState.findInProgressState() else { return }

        Task {
            try? await taskManager.updateTaskState(task: ticket, newState: inProgressState.id)
        }
    }

    func promptCompletionStateChange(ticketId: String) {
        guard let appState = appState,
            let taskManager = taskManager
        else { return }

        guard let ticket = taskManager.tasks.first(where: { $0.id == ticketId }),
            let completedState = appState.findCompletedState()
        else { return }

        appState.pendingStateChangeConfirmation = PendingStateChange(
            ticketId: ticketId,
            ticketIdentifier: ticket.identifier,
            targetState: completedState
        )
    }
}
