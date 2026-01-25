import Foundation

public struct TransitionRecord: Codable, Equatable, Identifiable {
    public let id: UUID
    public let date: Date
    public let duration: TimeInterval
    public let fromTicketId: String?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: TimeInterval,
        fromTicketId: String?
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.fromTicketId = fromTicketId
    }
}
