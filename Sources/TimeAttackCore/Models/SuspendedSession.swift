import Foundation

public struct SuspendedSession: Codable, Equatable {
    public let ticketId: String
    public let remainingTime: TimeInterval
    public let suspendedAt: Date

    public init(ticketId: String, remainingTime: TimeInterval, suspendedAt: Date) {
        self.ticketId = ticketId
        self.remainingTime = remainingTime
        self.suspendedAt = suspendedAt
    }
}
