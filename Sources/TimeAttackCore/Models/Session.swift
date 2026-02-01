import Foundation

public struct PausedInterval: Codable, Equatable {
    public let start: Date
    public let end: Date?

    public init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    public var duration: TimeInterval {
        let endTime = end ?? Date()
        return endTime.timeIntervalSince(start)
    }

    public func withEnd(_ end: Date) -> PausedInterval {
        PausedInterval(start: start, end: end)
    }
}

public struct Session: Identifiable, Codable, Equatable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date?
    public let tasks: [SessionTask]

    public init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        tasks: [SessionTask] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.tasks = tasks
    }

    public var isActive: Bool {
        endTime == nil
    }

    public var activeTask: SessionTask? {
        tasks.first { $0.isActive }
    }

    public var totalDuration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    public var totalWorkTime: TimeInterval {
        tasks
            .filter { $0.type.isWork }
            .reduce(0) { $0 + $1.actualDuration }
    }

    public var totalRestTime: TimeInterval {
        tasks
            .filter { $0.type.isRest }
            .reduce(0) { $0 + $1.actualDuration }
    }

    public var totalDecidingTime: TimeInterval {
        tasks
            .filter { $0.type.isDeciding }
            .reduce(0) { $0 + $1.actualDuration }
    }

    public var totalTransitionTime: TimeInterval {
        tasks
            .filter { $0.type.isTransitioning }
            .reduce(0) { $0 + $1.actualDuration }
    }

    public var totalOverheadTime: TimeInterval {
        totalDecidingTime + totalTransitionTime
    }

    public var workTasks: [SessionTask] {
        tasks.filter { $0.type.isWork }
    }

    public var uniqueTicketIds: [String] {
        tasks.compactMap { $0.type.ticketId }
            .reduce(into: [String]()) { result, ticketId in
                if !result.contains(ticketId) {
                    result.append(ticketId)
                }
            }
    }

    public func workTimeForTicket(_ ticketId: String) -> TimeInterval {
        tasks
            .filter { $0.type.ticketId == ticketId }
            .reduce(0) { $0 + $1.actualDuration }
    }

    public func withTasks(_ tasks: [SessionTask]) -> Session {
        Session(
            id: id,
            startTime: startTime,
            endTime: endTime,
            tasks: tasks
        )
    }

    public func withEndTime(_ endTime: Date) -> Session {
        Session(
            id: id,
            startTime: startTime,
            endTime: endTime,
            tasks: tasks
        )
    }

    public func appendingTask(_ task: SessionTask) -> Session {
        Session(
            id: id,
            startTime: startTime,
            endTime: endTime,
            tasks: tasks + [task]
        )
    }

    public func updatingTask(_ task: SessionTask) -> Session {
        let updatedTasks = tasks.map { $0.id == task.id ? task : $0 }
        return Session(
            id: id,
            startTime: startTime,
            endTime: endTime,
            tasks: updatedTasks
        )
    }
}
