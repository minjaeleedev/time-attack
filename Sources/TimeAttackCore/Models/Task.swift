import Foundation

public struct SessionTask: Identifiable, Codable, Equatable {
    public let id: UUID
    public let sessionId: UUID
    public let type: TaskType
    public let startTime: Date
    public let endTime: Date?
    public let pausedIntervals: [PausedInterval]
    public let initialRemainingTime: TimeInterval?

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        type: TaskType,
        startTime: Date = Date(),
        endTime: Date? = nil,
        pausedIntervals: [PausedInterval] = [],
        initialRemainingTime: TimeInterval? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.pausedIntervals = pausedIntervals
        self.initialRemainingTime = initialRemainingTime
    }

    public var totalPausedTime: TimeInterval {
        pausedIntervals.reduce(0) { total, interval in
            guard let end = interval.end else { return total }
            return total + end.timeIntervalSince(interval.start)
        }
    }

    public var actualDuration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime) - totalPausedTime
    }

    public var isActive: Bool {
        endTime == nil
    }

    public var isPaused: Bool {
        guard let lastInterval = pausedIntervals.last else { return false }
        return lastInterval.end == nil
    }

    public func withEndTime(_ endTime: Date) -> SessionTask {
        SessionTask(
            id: id,
            sessionId: sessionId,
            type: type,
            startTime: startTime,
            endTime: endTime,
            pausedIntervals: pausedIntervals,
            initialRemainingTime: initialRemainingTime
        )
    }

    public func withPausedIntervals(_ intervals: [PausedInterval]) -> SessionTask {
        SessionTask(
            id: id,
            sessionId: sessionId,
            type: type,
            startTime: startTime,
            endTime: endTime,
            pausedIntervals: intervals,
            initialRemainingTime: initialRemainingTime
        )
    }
}
