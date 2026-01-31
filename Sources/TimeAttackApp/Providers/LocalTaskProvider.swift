import Foundation
import TimeAttackCore

final class LocalTaskProvider: IssueTrackerProvider {
    static let shared = LocalTaskProvider()

    var providerType: String { "Local" }
    var isAuthenticated: Bool { true }

    private init() {}

    func fetchTasks() async throws -> [Ticket] {
        LocalStorage.shared.loadLocalTasks()
    }

    func createTask(_ request: TaskCreateRequest) async throws -> Ticket {
        let taskNumber = LocalStorage.shared.getNextLocalTaskNumber()
        let id = UUID().uuidString
        let identifier = "LOCAL-\(taskNumber)"

        let ticket = Ticket(
            id: id,
            identifier: identifier,
            title: request.title,
            state: LocalTaskState.todo.displayName,
            source: .local,
            priority: request.priority ?? 0,
            updatedAt: Date(),
            createdAt: Date(),
            dueDate: request.dueDate
        )

        var tasks = LocalStorage.shared.loadLocalTasks()
        tasks.insert(ticket, at: 0)
        LocalStorage.shared.saveLocalTasks(tasks)

        return ticket
    }

    func updateTaskState(taskId: String, newState: String) async throws -> Ticket {
        var tasks = LocalStorage.shared.loadLocalTasks()

        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
            throw ProviderError.operationFailed("Task not found")
        }

        let updatedTicket = tasks[index].withState(newState)
        tasks[index] = updatedTicket
        LocalStorage.shared.saveLocalTasks(tasks)

        return updatedTicket
    }

    func deleteTask(taskId: String) async throws {
        var tasks = LocalStorage.shared.loadLocalTasks()
        tasks.removeAll { $0.id == taskId }
        LocalStorage.shared.saveLocalTasks(tasks)
    }

    func updateTaskNotes(taskId: String, notes: String?) async throws -> Ticket {
        var tasks = LocalStorage.shared.loadLocalTasks()

        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
            throw ProviderError.operationFailed("Task not found")
        }

        let updatedTicket = tasks[index].withNotes(notes)
        tasks[index] = updatedTicket
        LocalStorage.shared.saveLocalTasks(tasks)

        return updatedTicket
    }
}
