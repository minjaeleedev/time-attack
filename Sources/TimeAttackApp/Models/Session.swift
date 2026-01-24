import Foundation

struct PausedInterval: Codable, Equatable {
    let start: Date
    var end: Date?
}

struct Session: Identifiable, Codable, Equatable {
    let id: UUID
    let ticketId: String
    let startTime: Date
    var endTime: Date?
    var pausedIntervals: [PausedInterval]
    
    init(ticketId: String) {
        self.id = UUID()
        self.ticketId = ticketId
        self.startTime = Date()
        self.endTime = nil
        self.pausedIntervals = []
    }
    
    var totalPausedTime: TimeInterval {
        pausedIntervals.reduce(0) { total, interval in
            guard let end = interval.end else { return total }
            return total + end.timeIntervalSince(interval.start)
        }
    }
    
    var actualDuration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime) - totalPausedTime
    }
    
    var isActive: Bool {
        endTime == nil
    }
    
    var isPaused: Bool {
        guard let lastInterval = pausedIntervals.last else { return false }
        return lastInterval.end == nil
    }
}
