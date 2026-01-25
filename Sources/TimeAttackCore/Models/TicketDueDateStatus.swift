import Foundation

public enum TicketDueDateStatus: Equatable {
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
