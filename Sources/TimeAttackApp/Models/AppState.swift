import Foundation
import TimeAttackCore

struct PendingStateChange: Identifiable {
    let id = UUID()
    let ticketId: String
    let ticketIdentifier: String
    let targetState: WorkflowState
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

    // Linear API related state
    @Published var teams: [Team] = []
    @Published var workflowStates: [String: [WorkflowState]] = [:]
    @Published var showCreateIssueSheet = false
    @Published var isCreatingIssue = false
    @Published var isUpdatingIssueState = false
    @Published var selectedTeamId: String?
    @Published var pendingStateChangeConfirmation: PendingStateChange?

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
        teams = []
        workflowStates = [:]
        selectedTeamId = nil
    }

    // MARK: - Linear API Methods

    func loadTeams() async {
        guard let token = accessToken else { return }

        do {
            teams = try await LinearGraphQLClient.shared.fetchTeams(accessToken: token)
            if selectedTeamId == nil, let firstTeam = teams.first {
                selectedTeamId = firstTeam.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadWorkflowStates(for teamId: String) async {
        guard let token = accessToken else { return }
        guard workflowStates[teamId] == nil else { return }

        do {
            let states = try await LinearGraphQLClient.shared.fetchWorkflowStates(
                teamId: teamId,
                accessToken: token
            )
            workflowStates[teamId] = states
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createIssue(
        title: String,
        teamId: String,
        description: String?,
        priority: Int?,
        estimate: Int?
    ) async -> Bool {
        guard let token = accessToken else { return false }

        isCreatingIssue = true
        defer { isCreatingIssue = false }

        do {
            let newTicket = try await LinearGraphQLClient.shared.createIssue(
                title: title,
                teamId: teamId,
                description: description,
                priority: priority,
                estimate: estimate,
                accessToken: token
            )
            tickets.insert(newTicket, at: 0)
            LocalStorage.shared.saveTickets(tickets)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateIssueState(ticketId: String, stateId: String) async -> Bool {
        guard let token = accessToken else { return false }

        isUpdatingIssueState = true
        defer { isUpdatingIssueState = false }

        do {
            let newStateName = try await LinearGraphQLClient.shared.updateIssueState(
                issueId: ticketId,
                stateId: stateId,
                accessToken: token
            )

            if let index = tickets.firstIndex(where: { $0.id == ticketId }) {
                tickets[index] = tickets[index].withState(newStateName)
                LocalStorage.shared.saveTickets(tickets)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func workflowStatesForCurrentTeam() -> [WorkflowState] {
        guard let teamId = selectedTeamId else { return [] }
        return workflowStates[teamId] ?? []
    }

    func findInProgressState() -> WorkflowState? {
        workflowStatesForCurrentTeam().first { $0.isStarted }
    }

    func findCompletedState() -> WorkflowState? {
        workflowStatesForCurrentTeam().first { $0.isCompleted }
    }
}
