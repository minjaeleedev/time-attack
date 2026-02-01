import Foundation
import TimeAttackCore

@MainActor
final class TaskManager: ObservableObject {
    @Published private(set) var tasks: [Ticket] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var providerSettings: ProviderSettings
    @Published var isCreatingTask = false
    @Published var isUpdatingTaskState = false

    private var linearProvider: LinearProvider?
    private let localProvider = LocalTaskProvider.shared

    init() {
        self.providerSettings = LocalStorage.shared.loadProviderSettings()
        loadCachedTasks()
    }

    var localTasks: [Ticket] {
        tasks.filter { $0.isLocal }
    }

    var linearTasks: [Ticket] {
        tasks.filter { !$0.isLocal }
    }

    func configureLinear(accessToken: String, teamId: String?) {
        linearProvider = LinearProvider(accessToken: accessToken, teamId: teamId)
    }

    func updateProviderSettings(_ settings: ProviderSettings) {
        providerSettings = settings
        LocalStorage.shared.saveProviderSettings(settings)
    }

    func refreshAllTasks() async {
        isLoading = true
        defer { isLoading = false }

        var allTasks: [Ticket] = []
        errorMessage = nil

        if providerSettings.localEnabled {
            do {
                let localTasks = try await localProvider.fetchTasks()
                allTasks.append(contentsOf: localTasks)
            } catch {
                errorMessage = "Failed to load local tasks: \(error.localizedDescription)"
            }
        }

        if providerSettings.linearEnabled, let linear = linearProvider {
            do {
                let linearTasks = try await linear.fetchTasks()
                allTasks.append(contentsOf: linearTasks)
                LocalStorage.shared.saveTickets(linearTasks)
            } catch ProviderError.notAuthenticated {
                errorMessage = "Linear authentication expired. Please reconnect."
            } catch {
                let cachedTickets = LocalStorage.shared.loadTickets()
                allTasks.append(contentsOf: cachedTickets)
                errorMessage = "Using cached Linear data: \(error.localizedDescription)"
            }
        }

        tasks = sortedTasks(allTasks)
    }

    func createTask(
        _ request: TaskCreateRequest,
        providerType: String
    ) async throws -> Ticket {
        isCreatingTask = true
        defer { isCreatingTask = false }

        let ticket: Ticket

        if providerType == "Local" {
            ticket = try await localProvider.createTask(request)
        } else if providerType == "Linear", let linear = linearProvider {
            ticket = try await linear.createTask(request)
        } else {
            throw ProviderError.operationFailed("Provider not available")
        }

        tasks.insert(ticket, at: 0)
        tasks = sortedTasks(tasks)

        return ticket
    }

    func updateTaskState(task: Ticket, newState: String) async throws {
        isUpdatingTaskState = true
        defer { isUpdatingTaskState = false }

        let updatedTicket: Ticket

        if task.isLocal {
            updatedTicket = try await localProvider.updateTaskState(
                taskId: task.id,
                newState: newState
            )
        } else if let linear = linearProvider {
            updatedTicket = try await linear.updateTaskState(
                taskId: task.id,
                newState: newState
            )
        } else {
            throw ProviderError.operationFailed("Provider not available")
        }

        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = updatedTicket
        }
    }

    func deleteTask(_ task: Ticket) async throws {
        guard task.isLocal else {
            throw ProviderError.operationFailed("Only local tasks can be deleted")
        }

        try await localProvider.deleteTask(taskId: task.id)
        tasks.removeAll { $0.id == task.id }
    }

    func updateLocalEstimate(taskId: String, estimate: TimeInterval) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index] = tasks[index].withLocalEstimate(estimate)
            LocalStorage.shared.saveEstimate(ticketId: taskId, estimate: estimate)

            if tasks[index].isLocal {
                LocalStorage.shared.saveLocalTasks(localTasks)
            } else {
                LocalStorage.shared.saveTickets(linearTasks)
            }
        }
    }

    private func loadCachedTasks() {
        var cached: [Ticket] = []

        if providerSettings.localEnabled {
            cached.append(contentsOf: LocalStorage.shared.loadLocalTasks())
        }

        if providerSettings.linearEnabled {
            cached.append(contentsOf: LocalStorage.shared.loadTickets())
        }

        tasks = sortedTasks(cached)
    }

    private func sortedTasks(_ tasks: [Ticket]) -> [Ticket] {
        tasks.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
