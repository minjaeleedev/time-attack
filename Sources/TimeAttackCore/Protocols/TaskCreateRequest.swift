import Foundation

public struct TaskCreateRequest {
    public let title: String
    public let description: String?
    public let priority: Int?
    public let estimate: Int?
    public let dueDate: Date?
    public let teamId: String?

    public init(
        title: String,
        description: String? = nil,
        priority: Int? = nil,
        estimate: Int? = nil,
        dueDate: Date? = nil,
        teamId: String? = nil
    ) {
        self.title = title
        self.description = description
        self.priority = priority
        self.estimate = estimate
        self.dueDate = dueDate
        self.teamId = teamId
    }
}
