import Foundation

public enum TaskSource: Codable, Equatable, Hashable {
    case local
    case linear(issueId: String, url: String)
    case jira(issueKey: String, url: String)

    public var providerName: String {
        switch self {
        case .local:
            return "Local"
        case .linear:
            return "Linear"
        case .jira:
            return "Jira"
        }
    }

    public var externalUrl: URL? {
        switch self {
        case .local:
            return nil
        case .linear(_, let url), .jira(_, let url):
            return URL(string: url)
        }
    }

    public var isExternal: Bool {
        switch self {
        case .local:
            return false
        case .linear, .jira:
            return true
        }
    }

    public var externalId: String? {
        switch self {
        case .local:
            return nil
        case .linear(let issueId, _):
            return issueId
        case .jira(let issueKey, _):
            return issueKey
        }
    }
}
