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
    public let dueDate: Date?
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
        dueDate: Date? = nil,
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
        self.dueDate = dueDate
        self.parentId = parentId
        self.children = children
    }

    public var dueDateStatus: TicketDueDateStatus {
        guard let dueDate = dueDate else { return .none }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDateStart = calendar.startOfDay(for: dueDate)

        let components = calendar.dateComponents([.day], from: today, to: dueDateStart)
        guard let days = components.day else { return .none }

        switch days {
        case ..<0:
            return .overdue(days: abs(days))
        case 0:
            return .today
        case 1...3:
            return .soon(days: days)
        default:
            return .normal(days: days)
        }
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

    public func withState(_ newState: String, updatedAt: Date = Date()) -> Ticket {
        Ticket(
            id: id,
            identifier: identifier,
            title: title,
            url: url,
            state: newState,
            linearEstimate: linearEstimate,
            localEstimate: localEstimate,
            priority: priority,
            updatedAt: updatedAt,
            dueDate: dueDate,
            parentId: parentId,
            children: children
        )
    }
}
