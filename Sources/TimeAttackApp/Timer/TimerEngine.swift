import Foundation
import TimeAttackCore
import UserNotifications

@MainActor
final class TimerEngine: ObservableObject {
    static let shared = TimerEngine()

    private weak var appState: AppState?

    private init() {
        requestNotificationPermission()
    }

    func setAppState(_ state: AppState) {
        self.appState = state
        state.sessions = LocalStorage.shared.loadSessions()
        state.suspendedSessions = LocalStorage.shared.loadSuspendedSessions()
        state.transitionRecords = LocalStorage.shared.loadTransitionRecords()
    }

    // MARK: - Work Session

    func switchTo(ticketId: String) {
        stopSession()
        startWorkSession(ticketId: ticketId)
    }

    func startWorkSession(ticketId: String) {
        guard let appState = appState else { return }

        let session = Session(ticketId: ticketId, mode: .work(ticketId: ticketId))
        appState.activeSession = session
        appState.sessions.append(session)
        saveSessions()
    }

    // MARK: - Rest Session

    func startRestSession(duration: TimeInterval) {
        guard let appState = appState else { return }

        stopSession()

        let session = Session.restSession(duration: duration)
        appState.activeSession = session
        appState.sessions.append(session)
        saveSessions()

        scheduleRestEndNotification(duration: duration)
    }

    func switchToRest(duration: TimeInterval) {
        startRestSession(duration: duration)
    }

    func switchToWork(ticketId: String) {
        stopSession()
        resumeWorkSession(ticketId: ticketId)
    }

    // MARK: - Suspend/Resume

    func suspendCurrentSession(remainingTime: TimeInterval) {
        guard let appState = appState,
              let session = appState.activeSession,
              session.mode.isWork else { return }

        let suspended = SuspendedSession(
            ticketId: session.ticketId,
            remainingTime: remainingTime,
            suspendedAt: Date()
        )
        appState.suspendedSessions[session.ticketId] = suspended
        saveSuspendedSessions()

        stopSession()
    }

    func resumeWorkSession(ticketId: String) {
        guard let appState = appState else { return }

        if let suspended = appState.suspendedSessions[ticketId] {
            let session = Session(
                ticketId: ticketId,
                mode: .work(ticketId: ticketId),
                initialRemainingTime: suspended.remainingTime
            )
            appState.activeSession = session
            appState.sessions.append(session)

            appState.suspendedSessions.removeValue(forKey: ticketId)
            saveSuspendedSessions()
            saveSessions()
        } else {
            startWorkSession(ticketId: ticketId)
        }
    }

    // MARK: - Session Control

    @available(*, deprecated, renamed: "startWorkSession")
    func startSession(ticketId: String) {
        startWorkSession(ticketId: ticketId)
    }

    func stopSession() {
        guard let appState = appState,
              var session = appState.activeSession else { return }

        if session.isPaused {
            session.pausedIntervals[session.pausedIntervals.count - 1].end = Date()
        }

        session.endTime = Date()

        if let index = appState.sessions.firstIndex(where: { $0.id == session.id }) {
            appState.sessions[index] = session
        }

        appState.activeSession = nil
        saveSessions()

        cancelPendingNotifications()
    }

    func togglePause() {
        guard let appState = appState,
              var session = appState.activeSession else { return }

        if session.isPaused {
            session.pausedIntervals[session.pausedIntervals.count - 1].end = Date()
        } else {
            session.pausedIntervals.append(PausedInterval(start: Date(), end: nil))
        }

        appState.activeSession = session

        if let index = appState.sessions.firstIndex(where: { $0.id == session.id }) {
            appState.sessions[index] = session
        }

        saveSessions()
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleRestEndNotification(duration: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "휴식 종료"
        content.body = "휴식 시간이 끝났습니다. 작업을 시작할 준비가 되셨나요?"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(identifier: "rest-end", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelPendingNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-end"])
    }
}
