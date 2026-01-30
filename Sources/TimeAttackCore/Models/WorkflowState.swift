import Foundation

public struct WorkflowState: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let type: String
    public let color: String
    public let position: Double

    public init(
        id: String,
        name: String,
        type: String,
        color: String,
        position: Double
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.color = color
        self.position = position
    }

    public var isStarted: Bool {
        type == "started"
    }

    public var isCompleted: Bool {
        type == "completed"
    }

    public var isCanceled: Bool {
        type == "canceled"
    }

    public var isUnstarted: Bool {
        type == "unstarted"
    }

    public var isBacklog: Bool {
        type == "backlog"
    }
}
