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
    @Published var sessions: [Session] = []
    @Published var currentSession: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pendingEstimateTicketId: String?
    @Published var showingSessionStart = false
    @Published var showingTaskSelection = false
    @Published var showingTaskSwitch = false
    @Published var showingSessionReport = false
    @Published var suspendedSessions: [String: SuspendedSession] = [:]
    @Published var transitionRecords: [TransitionRecord] = []
    @Published var completedSession: Session?

    // Linear API related state
    @Published var teams: [Team] = []
    @Published var workflowStates: [String: [WorkflowState]] = [:]
    @Published var showCreateIssueSheet = false
    @Published var selectedTeamId: String?
    @Published var pendingStateChangeConfirmation: PendingStateChange?

    var isAuthenticated: Bool {
        authState.isAuthenticated
    }

    var accessToken: String? {
        authState.accessToken
    }

    var activeSession: Session? {
        currentSession
    }

    var activeTask: SessionTask? {
        currentSession?.activeTask
    }

    var activeWorkTicketId: String? {
        guard let task = activeTask, task.type.isWork else { return nil }
        return task.type.ticketId
    }

    func logout() {
        try? KeychainManager.shared.deleteAccessToken()
        authState = .unauthenticated
        sessions = []
        currentSession = nil
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
