import Foundation

public enum SessionMode: Codable, Equatable {
    case work(ticketId: String)
    case rest(duration: TimeInterval)

    public var isWork: Bool {
        if case .work = self { return true }
        return false
    }

    public var isRest: Bool {
        if case .rest = self { return true }
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
}
