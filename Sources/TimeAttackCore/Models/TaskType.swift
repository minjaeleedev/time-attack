import Foundation

public enum TaskType: Codable, Equatable {
    case work(ticketId: String)
    case rest(duration: TimeInterval)
    case deciding
    case transitioning(fromTicketId: String?)

    public var isWork: Bool {
        if case .work = self { return true }
        return false
    }

    public var isRest: Bool {
        if case .rest = self { return true }
        return false
    }

    public var isDeciding: Bool {
        if case .deciding = self { return true }
        return false
    }

    public var isTransitioning: Bool {
        if case .transitioning = self { return true }
        return false
    }

    public var ticketId: String? {
        if case .work(let id) = self { return id }
        return nil
    }

    public var restDuration: TimeInterval? {
        if case .rest(let duration) = self { return duration }
        return nil
    }

    public var fromTicketId: String? {
        if case .transitioning(let id) = self { return id }
        return nil
    }

    public var displayName: String {
        switch self {
        case .work:
            return "작업"
        case .rest:
            return "휴식"
        case .deciding:
            return "결정 중"
        case .transitioning:
            return "전환 중"
        }
    }
}
