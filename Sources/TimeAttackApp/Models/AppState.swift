import Foundation
import TimeAttackCore

@MainActor
final class AppState: ObservableObject {
    @Published var authState: AuthState = .unauthenticated
    @Published var tickets: [Ticket] = []
    @Published var sessions: [Session] = []
    @Published var activeSession: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?

    var isAuthenticated: Bool {
        authState.isAuthenticated
    }

    var accessToken: String? {
        authState.accessToken
    }

    func logout() {
        try? KeychainManager.shared.deleteAccessToken()
        authState = .unauthenticated
        tickets = []
        sessions = []
        activeSession = nil
    }
}
