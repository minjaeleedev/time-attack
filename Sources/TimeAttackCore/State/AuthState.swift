import Foundation

public enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(accessToken: String)
    case error(String)

    public var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }

    public var accessToken: String? {
        if case .authenticated(let token) = self { return token }
        return nil
    }
}
