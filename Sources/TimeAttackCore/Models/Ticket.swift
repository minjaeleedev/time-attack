import Foundation

public struct Ticket: Identifiable, Codable, Equatable {
    public let id: String
    public let identifier: String
    public let title: String
    public let state: String
    public let source: TaskSource
    public let priority: Int
    public let updatedAt: Date
    public let createdAt: Date
    public let dueDate: Date?
    public let parentId: String?
    public var children: [Ticket]
    public var localEstimate: TimeInterval?
    public var notes: String?
    public let externalEstimate: Int?

    public init(
        id: String,
        identifier: String,
        title: String,
        state: String,
        source: TaskSource,
        priority: Int,
        updatedAt: Date,
        createdAt: Date = Date(),
        dueDate: Date? = nil,
        parentId: String? = nil,
        children: [Ticket] = [],
        localEstimate: TimeInterval? = nil,
        notes: String? = nil,
        externalEstimate: Int? = nil
    ) {
        self.id = id
        self.identifier = identifier
        self.title = title
        self.state = state
        self.source = source
        self.priority = priority
        self.updatedAt = updatedAt
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.parentId = parentId
        self.children = children
        self.localEstimate = localEstimate
        self.notes = notes
        self.externalEstimate = externalEstimate
    }

    public var url: String? {
        source.externalUrl?.absoluteString
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
        if let external = externalEstimate {
            return "\(external) pts"
        }
        return "No estimate"
    }

    public var isLocal: Bool {
        !source.isExternal
    }

    public func withState(_ newState: String, updatedAt: Date = Date()) -> Ticket {
        Ticket(
            id: id,
            identifier: identifier,
            title: title,
            state: newState,
            source: source,
            priority: priority,
            updatedAt: updatedAt,
            createdAt: createdAt,
            dueDate: dueDate,
            parentId: parentId,
            children: children,
            localEstimate: localEstimate,
            notes: notes,
            externalEstimate: externalEstimate
        )
    }

    public func withNotes(_ newNotes: String?) -> Ticket {
        Ticket(
            id: id,
            identifier: identifier,
            title: title,
            state: state,
            source: source,
            priority: priority,
            updatedAt: Date(),
            createdAt: createdAt,
            dueDate: dueDate,
            parentId: parentId,
            children: children,
            localEstimate: localEstimate,
            notes: newNotes,
            externalEstimate: externalEstimate
        )
    }

    public func withLocalEstimate(_ estimate: TimeInterval?) -> Ticket {
        Ticket(
            id: id,
            identifier: identifier,
            title: title,
            state: state,
            source: source,
            priority: priority,
            updatedAt: Date(),
            createdAt: createdAt,
            dueDate: dueDate,
            parentId: parentId,
            children: children,
            localEstimate: estimate,
            notes: notes,
            externalEstimate: externalEstimate
        )
    }
}
