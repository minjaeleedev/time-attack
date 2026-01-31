import Foundation

public enum ProviderError: Error, LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case invalidResponse
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        case .operationFailed(let message):
            return message
        }
    }
}

public protocol IssueTrackerProvider {
    var providerType: String { get }
    var isAuthenticated: Bool { get }

    func fetchTasks() async throws -> [Ticket]
    func createTask(_ request: TaskCreateRequest) async throws -> Ticket
    func updateTaskState(taskId: String, newState: String) async throws -> Ticket
    func deleteTask(taskId: String) async throws
}

public extension IssueTrackerProvider {
    func deleteTask(taskId: String) async throws {
        throw ProviderError.operationFailed("Delete not supported by this provider")
    }
}
