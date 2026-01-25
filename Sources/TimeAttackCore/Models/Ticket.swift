import Foundation

public enum DueDateStatus: Equatable {
    case overdue(days: Int)
    case today
    case soon(days: Int)
    case normal(days: Int)
    case none

    public var displayText: String {
        switch self {
        case .overdue(let days):
            return days == 1 ? "1일 지남" : "\(days)일 지남"
        case .today:
            return "오늘 마감"
        case .soon(let days):
            return days == 1 ? "내일 마감" : "\(days)일 남음"
        case .normal(let days):
            return "\(days)일 남음"
        case .none:
            return ""
        }
    }

    public var color: String {
        switch self {
        case .overdue: return "red"
        case .today: return "orange"
        case .soon: return "yellow"
        case .normal: return "secondary"
        case .none: return "clear"
        }
    }
}

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

    public var dueDateStatus: DueDateStatus {
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
}
