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
                url: node.url,
                state: node.state.name,
                linearEstimate: node.estimate,
                localEstimate: estimates[node.id],
                priority: node.priority,
                updatedAt: dateFormatter.date(from: node.updatedAt) ?? Date(),
                dueDate: dueDate,
                parentId: node.parent?.id,
                children: children
            )
        }

        return nodes.map { convertNode($0) }
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
