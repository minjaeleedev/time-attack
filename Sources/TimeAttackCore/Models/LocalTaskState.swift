import Foundation

public enum LocalTaskState: String, Codable, Equatable, CaseIterable {
    case todo = "Todo"
    case inProgress = "In Progress"
    case done = "Done"

    public var displayName: String {
        rawValue
    }

    public var isStarted: Bool {
        self == .inProgress
    }

    public var isCompleted: Bool {
        self == .done
    }

    public func next() -> LocalTaskState {
        switch self {
        case .todo:
            return .inProgress
        case .inProgress:
            return .done
        case .done:
            return .done
        }
    }
}
