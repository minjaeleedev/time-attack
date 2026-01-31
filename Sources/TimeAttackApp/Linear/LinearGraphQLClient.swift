import Foundation
import TimeAttackCore

final class LinearGraphQLClient {
    static let shared = LinearGraphQLClient()
    
    private let endpoint = URL(string: "https://api.linear.app/graphql")!
    
    private init() {}
    
    func fetchAssignedIssues(accessToken: String) async throws -> [Ticket] {
        let query = """
        query {
          viewer {
            assignedIssues(first: 50, filter: { state: { type: { nin: ["completed", "canceled"] } } }) {
              nodes {
                id
                identifier
                title
                url
                state {
                  name
                }
                estimate
                priority
                updatedAt
                dueDate
                parent {
                  id
                }
                children {
                  nodes {
                    id
                    identifier
                    title
                    url
                    state {
                      name
                    }
                    estimate
                    priority
                    updatedAt
                    dueDate
                    parent {
                      id
                    }
                    children {
                      nodes {
                        id
                        identifier
                        title
                        url
                        state {
                          name
                        }
                        estimate
                        priority
                        updatedAt
                        dueDate
                        parent {
                          id
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = ["query": query]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)

        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[Linear API Response]")
            print(jsonString)
        }
        #endif

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LinearAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw LinearAPIError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw LinearAPIError.httpError(httpResponse.statusCode)
        }

        let graphQLResponse = try JSONDecoder().decode(GraphQLResponse.self, from: data)
        
        if let errors = graphQLResponse.errors, !errors.isEmpty {
            throw LinearAPIError.graphQLError(errors.first?.message ?? "Unknown error")
        }
        
        guard let nodes = graphQLResponse.data?.viewer.assignedIssues.nodes else {
            return []
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dueDateFormatter = DateFormatter()
        dueDateFormatter.dateFormat = "yyyy-MM-dd"

        let estimates = LocalStorage.shared.loadEstimates()

        func convertNode(_ node: IssueNode) -> Ticket {
            let children = node.children?.nodes.map { convertNode($0) } ?? []
            let dueDate: Date? = node.dueDate.flatMap { dueDateFormatter.date(from: $0) }
            return Ticket(
                id: node.id,
                identifier: node.identifier,
                title: node.title,
                state: node.state.name,
                source: .linear(issueId: node.id, url: node.url),
                priority: node.priority,
                updatedAt: dateFormatter.date(from: node.updatedAt) ?? Date(),
                dueDate: dueDate,
                parentId: node.parent?.id,
                children: children,
                localEstimate: estimates[node.id],
                externalEstimate: node.estimate
            )
        }

        return nodes.map { convertNode($0) }
    }

    // MARK: - Fetch Teams

    func fetchTeams(accessToken: String) async throws -> [Team] {
        let query = """
        query {
          teams {
            nodes {
              id
              name
              key
            }
          }
        }
        """

        let data = try await executeQuery(query: query, accessToken: accessToken)
        let response = try JSONDecoder().decode(TeamsResponse.self, from: data)

        if let errors = response.errors, !errors.isEmpty {
            throw LinearAPIError.graphQLError(errors.first?.message ?? "Unknown error")
        }

        guard let nodes = response.data?.teams.nodes else {
            return []
        }

        return nodes.map { Team(id: $0.id, name: $0.name, key: $0.key) }
    }

    // MARK: - Fetch Workflow States

    func fetchWorkflowStates(teamId: String, accessToken: String) async throws -> [WorkflowState] {
        let query = """
        query($teamId: String!) {
          team(id: $teamId) {
            states {
              nodes {
                id
                name
                type
                color
                position
              }
            }
          }
        }
        """

        let data = try await executeQuery(
            query: query,
            variables: ["teamId": teamId],
            accessToken: accessToken
        )
        let response = try JSONDecoder().decode(WorkflowStatesResponse.self, from: data)

        if let errors = response.errors, !errors.isEmpty {
            throw LinearAPIError.graphQLError(errors.first?.message ?? "Unknown error")
        }

        guard let nodes = response.data?.team.states.nodes else {
            return []
        }

        return nodes.map {
            WorkflowState(
                id: $0.id,
                name: $0.name,
                type: $0.type,
                color: $0.color,
                position: $0.position
            )
        }.sorted { $0.position < $1.position }
    }

    // MARK: - Create Issue

    func createIssue(
        title: String,
        teamId: String,
        description: String?,
        priority: Int?,
        estimate: Int?,
        accessToken: String
    ) async throws -> Ticket {
        let mutation = """
        mutation($title: String!, $teamId: String!, $description: String, $priority: Int, $estimate: Int) {
          issueCreate(input: {
            title: $title
            teamId: $teamId
            description: $description
            priority: $priority
            estimate: $estimate
          }) {
            success
            issue {
              id
              identifier
              title
              url
              state {
                name
              }
              estimate
              priority
              updatedAt
              dueDate
            }
          }
        }
        """

        var variables: [String: Any] = [
            "title": title,
            "teamId": teamId
        ]
        if let description = description, !description.isEmpty {
            variables["description"] = description
        }
        if let priority = priority {
            variables["priority"] = priority
        }
        if let estimate = estimate {
            variables["estimate"] = estimate
        }

        let data = try await executeQuery(
            query: mutation,
            variables: variables,
            accessToken: accessToken
        )
        let response = try JSONDecoder().decode(CreateIssueResponse.self, from: data)

        if let errors = response.errors, !errors.isEmpty {
            throw LinearAPIError.graphQLError(errors.first?.message ?? "Unknown error")
        }

        guard let payload = response.data?.issueCreate,
              payload.success,
              let issue = payload.issue else {
            throw LinearAPIError.graphQLError("Failed to create issue")
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dueDateFormatter = DateFormatter()
        dueDateFormatter.dateFormat = "yyyy-MM-dd"

        let dueDate: Date? = issue.dueDate.flatMap { dueDateFormatter.date(from: $0) }

        return Ticket(
            id: issue.id,
            identifier: issue.identifier,
            title: issue.title,
            state: issue.state.name,
            source: .linear(issueId: issue.id, url: issue.url),
            priority: issue.priority,
            updatedAt: dateFormatter.date(from: issue.updatedAt) ?? Date(),
            dueDate: dueDate,
            externalEstimate: issue.estimate
        )
    }

    // MARK: - Update Issue State

    func updateIssueState(
        issueId: String,
        stateId: String,
        accessToken: String
    ) async throws -> String {
        let mutation = """
        mutation($issueId: String!, $stateId: String!) {
          issueUpdate(id: $issueId, input: { stateId: $stateId }) {
            success
            issue {
              id
              state {
                name
              }
            }
          }
        }
        """

        let variables: [String: Any] = [
            "issueId": issueId,
            "stateId": stateId
        ]

        let data = try await executeQuery(
            query: mutation,
            variables: variables,
            accessToken: accessToken
        )
        let response = try JSONDecoder().decode(UpdateIssueResponse.self, from: data)

        if let errors = response.errors, !errors.isEmpty {
            throw LinearAPIError.graphQLError(errors.first?.message ?? "Unknown error")
        }

        guard let payload = response.data?.issueUpdate,
              payload.success,
              let issue = payload.issue else {
            throw LinearAPIError.graphQLError("Failed to update issue state")
        }

        return issue.state.name
    }

    // MARK: - Helper Methods

    private func executeQuery(
        query: String,
        variables: [String: Any]? = nil,
        accessToken: String
    ) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = ["query": query]
        if let variables = variables {
            body["variables"] = variables
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[Linear API Response]")
            print(jsonString)
        }
        #endif

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LinearAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw LinearAPIError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw LinearAPIError.httpError(httpResponse.statusCode)
        }

        return data
    }
}

enum LinearAPIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case httpError(Int)
    case graphQLError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Linear API"
        case .unauthorized: return "Unauthorized. Please re-authenticate."
        case .httpError(let code): return "HTTP error: \(code)"
        case .graphQLError(let message): return "GraphQL error: \(message)"
        }
    }
}

private struct GraphQLResponse: Codable {
    let data: ResponseData?
    let errors: [GraphQLError]?
}

private struct ResponseData: Codable {
    let viewer: Viewer
}

private struct Viewer: Codable {
    let assignedIssues: IssueConnection
}

private struct IssueConnection: Codable {
    let nodes: [IssueNode]
}

private struct IssueNode: Codable {
    let id: String
    let identifier: String
    let title: String
    let url: String
    let state: IssueState
    let estimate: Int?
    let priority: Int
    let updatedAt: String
    let dueDate: String?
    let parent: ParentRef?
    let children: ChildrenConnection?
}

private struct ParentRef: Codable {
    let id: String
}

private struct ChildrenConnection: Codable {
    let nodes: [IssueNode]
}

private struct IssueState: Codable {
    let name: String
}

private struct GraphQLError: Codable {
    let message: String
}

// MARK: - Team Response Types

private struct TeamsResponse: Codable {
    let data: TeamsData?
    let errors: [GraphQLError]?
}

private struct TeamsData: Codable {
    let teams: TeamConnection
}

private struct TeamConnection: Codable {
    let nodes: [TeamNode]
}

private struct TeamNode: Codable {
    let id: String
    let name: String
    let key: String
}

// MARK: - WorkflowState Response Types

private struct WorkflowStatesResponse: Codable {
    let data: WorkflowStatesData?
    let errors: [GraphQLError]?
}

private struct WorkflowStatesData: Codable {
    let team: TeamWithStates
}

private struct TeamWithStates: Codable {
    let states: WorkflowStateConnection
}

private struct WorkflowStateConnection: Codable {
    let nodes: [WorkflowStateNode]
}

private struct WorkflowStateNode: Codable {
    let id: String
    let name: String
    let type: String
    let color: String
    let position: Double
}

// MARK: - Mutation Response Types

private struct CreateIssueResponse: Codable {
    let data: CreateIssueData?
    let errors: [GraphQLError]?
}

private struct CreateIssueData: Codable {
    let issueCreate: IssueCreatePayload
}

private struct IssueCreatePayload: Codable {
    let success: Bool
    let issue: CreatedIssueNode?
}

private struct CreatedIssueNode: Codable {
    let id: String
    let identifier: String
    let title: String
    let url: String
    let state: IssueState
    let estimate: Int?
    let priority: Int
    let updatedAt: String
    let dueDate: String?
}

private struct UpdateIssueResponse: Codable {
    let data: UpdateIssueData?
    let errors: [GraphQLError]?
}

private struct UpdateIssueData: Codable {
    let issueUpdate: IssueUpdatePayload
}

private struct IssueUpdatePayload: Codable {
    let success: Bool
    let issue: UpdatedIssueNode?
}

private struct UpdatedIssueNode: Codable {
    let id: String
    let state: IssueState
}
