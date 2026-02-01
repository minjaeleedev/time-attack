import Foundation
import TimeAttackCore

struct ProviderSettings: Codable, Equatable {
    var linearEnabled: Bool
    var localEnabled: Bool

    static let `default` = ProviderSettings(linearEnabled: true, localEnabled: true)
}

final class LocalStorage {
    static let shared = LocalStorage()

    private let ticketsKey = "cached_tickets"
    private let sessionsKey = "sessions"
    private let sessionsV2Key = "sessions_v2"
    private let estimatesKey = "local_estimates"
    private let suspendedSessionsKey = "suspended_sessions"
    private let transitionRecordsKey = "transition_records"
    private let localTasksKey = "local_tasks"
    private let providerSettingsKey = "provider_settings"
    private let localTaskCounterKey = "local_task_counter"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        migrateSessionsIfNeeded()
    }

    func saveTickets(_ tickets: [Ticket]) {
        guard let data = try? encoder.encode(tickets) else { return }
        UserDefaults.standard.set(data, forKey: ticketsKey)
    }

    func loadTickets() -> [Ticket] {
        guard let data = UserDefaults.standard.data(forKey: ticketsKey),
              let tickets = try? decoder.decode([Ticket].self, from: data) else {
            return []
        }
        return tickets
    }

    func saveSessions(_ sessions: [Session]) {
        guard let data = try? encoder.encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: sessionsV2Key)
    }

    func loadSessions() -> [Session] {
        guard let data = UserDefaults.standard.data(forKey: sessionsV2Key),
              let sessions = try? decoder.decode([Session].self, from: data) else {
            return []
        }
        return sessions
    }

    func saveEstimate(ticketId: String, estimate: TimeInterval) {
        var estimates = loadEstimates()
        estimates[ticketId] = estimate
        guard let data = try? encoder.encode(estimates) else { return }
        UserDefaults.standard.set(data, forKey: estimatesKey)
    }

    func loadEstimates() -> [String: TimeInterval] {
        guard let data = UserDefaults.standard.data(forKey: estimatesKey),
              let estimates = try? decoder.decode([String: TimeInterval].self, from: data) else {
            return [:]
        }
        return estimates
    }

    func saveSuspendedSessions(_ sessions: [String: SuspendedSession]) {
        guard let data = try? encoder.encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: suspendedSessionsKey)
    }

    func loadSuspendedSessions() -> [String: SuspendedSession] {
        guard let data = UserDefaults.standard.data(forKey: suspendedSessionsKey),
              let sessions = try? decoder.decode([String: SuspendedSession].self, from: data) else {
            return [:]
        }
        return sessions
    }

    func saveTransitionRecords(_ records: [TransitionRecord]) {
        guard let data = try? encoder.encode(records) else { return }
        UserDefaults.standard.set(data, forKey: transitionRecordsKey)
    }

    func loadTransitionRecords() -> [TransitionRecord] {
        guard let data = UserDefaults.standard.data(forKey: transitionRecordsKey),
              let records = try? decoder.decode([TransitionRecord].self, from: data) else {
            return []
        }
        return records
    }

    // MARK: - Local Tasks (from main)

    func saveLocalTasks(_ tasks: [Ticket]) {
        guard let data = try? encoder.encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: localTasksKey)
    }

    func loadLocalTasks() -> [Ticket] {
        guard let data = UserDefaults.standard.data(forKey: localTasksKey),
              let tasks = try? decoder.decode([Ticket].self, from: data) else {
            return []
        }
        return tasks
    }

    func saveProviderSettings(_ settings: ProviderSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: providerSettingsKey)
    }

    func loadProviderSettings() -> ProviderSettings {
        guard let data = UserDefaults.standard.data(forKey: providerSettingsKey),
              let settings = try? decoder.decode(ProviderSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func getNextLocalTaskNumber() -> Int {
        let current = UserDefaults.standard.integer(forKey: localTaskCounterKey)
        let next = current + 1
        UserDefaults.standard.set(next, forKey: localTaskCounterKey)
        return next
    }

    // MARK: - Migration (from feat-session-tasks)

    private func migrateSessionsIfNeeded() {
        guard UserDefaults.standard.data(forKey: sessionsV2Key) == nil,
              let oldData = UserDefaults.standard.data(forKey: sessionsKey) else {
            return
        }

        guard let oldSessions = try? decoder.decode([LegacySession].self, from: oldData) else {
            return
        }

        let migratedSessions = migrateToNewFormat(oldSessions: oldSessions)

        if let data = try? encoder.encode(migratedSessions) {
            UserDefaults.standard.set(data, forKey: sessionsV2Key)
        }
    }

    private func migrateToNewFormat(oldSessions: [LegacySession]) -> [Session] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: oldSessions) { session in
            calendar.startOfDay(for: session.startTime)
        }

        return grouped.map { (date, sessions) -> Session in
            let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }

            let sessionId = UUID()
            let startTime = sortedSessions.first?.startTime ?? date
            let endTime = sortedSessions.last?.endTime

            let tasks: [SessionTask] = sortedSessions.map { old in
                let taskType: TaskType = old.mode.isRest
                    ? .rest(duration: old.mode.restDuration ?? 300)
                    : .work(ticketId: old.ticketId)

                return SessionTask(
                    sessionId: sessionId,
                    type: taskType,
                    startTime: old.startTime,
                    endTime: old.endTime,
                    pausedIntervals: old.pausedIntervals,
                    initialRemainingTime: old.initialRemainingTime
                )
            }

            return Session(
                id: sessionId,
                startTime: startTime,
                endTime: endTime,
                tasks: tasks
            )
        }.sorted { $0.startTime < $1.startTime }
    }
}

// MARK: - Legacy Types for Migration

private struct LegacySession: Codable {
    let id: UUID
    let ticketId: String
    let startTime: Date
    var endTime: Date?
    var pausedIntervals: [PausedInterval]
    var mode: LegacySessionMode
    let initialRemainingTime: TimeInterval?
}

private enum LegacySessionMode: Codable {
    case work(ticketId: String)
    case rest(duration: TimeInterval)

    var isWork: Bool {
        if case .work = self { return true }
        return false
    }

    var isRest: Bool {
        if case .rest = self { return true }
        return false
    }

    var restDuration: TimeInterval? {
        if case .rest(let duration) = self { return duration }
        return nil
    }
}
