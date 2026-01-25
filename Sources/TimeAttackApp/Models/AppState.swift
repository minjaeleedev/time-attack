import Foundation
import TimeAttackCore

struct SuspendedSession: Codable, Equatable {
    let ticketId: String
    let remainingTime: TimeInterval
    let suspendedAt: Date
}

struct TransitionRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let fromTicketId: String?

    init(id: UUID = UUID(), date: Date = Date(), duration: TimeInterval, fromTicketId: String?) {
        self.id = id
        self.date = date
        self.duration = duration
        self.fromTicketId = fromTicketId
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var authState: AuthState = .unauthenticated
    @Published var tickets: [Ticket] = []
    @Published var sessions: [Session] = []
    @Published var activeSession: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pendingEstimateTicketId: String?
    @Published var showingSessionStart = false
    @Published var suspendedSessions: [String: SuspendedSession] = [:]
    @Published var transitionRecords: [TransitionRecord] = []

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
