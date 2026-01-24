import Foundation

enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(accessToken: String)
    case error(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var authState: AuthState = .unauthenticated
    @Published var tickets: [Ticket] = []
    @Published var sessions: [Session] = []
    @Published var activeSession: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }
    
    var accessToken: String? {
        if case .authenticated(let token) = authState { return token }
        return nil
    }
}
