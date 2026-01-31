import Foundation
import TimeAttackCore

final class LinearProvider: IssueTrackerProvider {
    var providerType: String { "Linear" }

    private let accessToken: String
    private let teamId: String?
    private let client = LinearGraphQLClient.shared

    var isAuthenticated: Bool { true }

    init(accessToken: String, teamId: String? = nil) {
        self.accessToken = accessToken
        self.teamId = teamId
    }

    func fetchTasks() async throws -> [Ticket] {
        do {
            return try await client.fetchAssignedIssues(accessToken: accessToken)
        } catch LinearAPIError.unauthorized {
            throw ProviderError.notAuthenticated
        } catch {
            throw ProviderError.networkError(error)
        }
    }

    func createTask(_ request: TaskCreateRequest) async throws -> Ticket {
        guard let teamId = request.teamId ?? self.teamId else {
            throw ProviderError.operationFailed("Team ID required for Linear issues")
        }

        do {
            return try await client.createIssue(
                title: request.title,
                teamId: teamId,
                description: request.description,
                priority: request.priority,
                estimate: request.estimate,
                accessToken: accessToken
            )
        } catch LinearAPIError.unauthorized {
            throw ProviderError.notAuthenticated
        } catch {
            throw ProviderError.networkError(error)
        }
    }

    func updateTaskState(taskId: String, newState: String) async throws -> Ticket {
        do {
            let newStateName = try await client.updateIssueState(
                issueId: taskId,
                stateId: newState,
                accessToken: accessToken
            )

            let tickets = try await fetchTasks()
            guard let ticket = tickets.first(where: { $0.id == taskId }) else {
                throw ProviderError.operationFailed("Task not found after update")
            }

            return ticket.withState(newStateName)
        } catch LinearAPIError.unauthorized {
            throw ProviderError.notAuthenticated
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
}
