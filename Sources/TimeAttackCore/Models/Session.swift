import Foundation

public struct PausedInterval: Codable, Equatable {
    public let start: Date
    public var end: Date?

    public init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }
}

public struct Session: Identifiable, Codable, Equatable {
    public let id: UUID
    public let ticketId: String
    public let startTime: Date
    public var endTime: Date?
    public var pausedIntervals: [PausedInterval]

    public init(
        id: UUID = UUID(),
        ticketId: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        pausedIntervals: [PausedInterval] = []
    ) {
        self.id = id
        self.ticketId = ticketId
        self.startTime = startTime
        self.endTime = endTime
        self.pausedIntervals = pausedIntervals
    }

    public var totalPausedTime: TimeInterval {
        pausedIntervals.reduce(0) { total, interval in
            guard let end = interval.end else { return total }
            return total + end.timeIntervalSince(interval.start)
        }
    }

    public var actualDuration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime) - totalPausedTime
    }

    public var isActive: Bool {
        endTime == nil
    }

    public var isPaused: Bool {
        guard let lastInterval = pausedIntervals.last else { return false }
        return lastInterval.end == nil
    }
}
