import Foundation

public struct Ticket: Identifiable, Codable, Equatable {
    public let id: String
    public let identifier: String
    public let title: String
    public let url: String
    public let state: String
    public let linearEstimate: Int?
    public var localEstimate: TimeInterval?
    public let priority: Int
    public let updatedAt: Date
    public let parentId: String?
    public var children: [Ticket]

    public init(
        id: String,
        identifier: String,
        title: String,
        url: String,
        state: String,
        linearEstimate: Int?,
        localEstimate: TimeInterval?,
        priority: Int,
        updatedAt: Date,
        parentId: String? = nil,
        children: [Ticket] = []
    ) {
        self.id = id
        self.identifier = identifier
        self.title = title
        self.url = url
        self.state = state
        self.linearEstimate = linearEstimate
        self.localEstimate = localEstimate
        self.priority = priority
        self.updatedAt = updatedAt
        self.parentId = parentId
        self.children = children
    }

    public var hasChildren: Bool {
        !children.isEmpty
    }

    public var allTickets: [Ticket] {
        [self] + children.flatMap { $0.allTickets }
    }

    public var displayEstimate: String {
        if let local = localEstimate {
            let hours = Int(local) / 3600
            let minutes = (Int(local) % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }
        if let linear = linearEstimate {
            return "\(linear) pts"
        }
        return "No estimate"
    }
}
