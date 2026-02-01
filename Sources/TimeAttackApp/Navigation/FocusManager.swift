import Foundation
import SwiftUI
import TimeAttackCore

@MainActor
final class FocusManager: ObservableObject {
    @Published var focusedTaskId: String?

    private weak var taskManager: TaskManager?

    func configure(with taskManager: TaskManager) {
        self.taskManager = taskManager
    }

    var focusedIndex: Int? {
        guard let id = focusedTaskId,
              let tasks = taskManager?.tasks else { return nil }
        return tasks.firstIndex { $0.id == id }
    }

    func moveUp() {
        guard let tasks = taskManager?.tasks, !tasks.isEmpty else { return }

        let newId: String?
        if let currentIndex = focusedIndex {
            let newIndex = max(0, currentIndex - 1)
            newId = tasks[newIndex].id
        } else {
            newId = tasks.first?.id
        }

        Task { @MainActor in
            focusedTaskId = newId
        }
    }

    func moveDown() {
        guard let tasks = taskManager?.tasks, !tasks.isEmpty else { return }

        let newId: String?
        if let currentIndex = focusedIndex {
            let newIndex = min(tasks.count - 1, currentIndex + 1)
            newId = tasks[newIndex].id
        } else {
            newId = tasks.first?.id
        }

        Task { @MainActor in
            focusedTaskId = newId
        }
    }

    func selectFirst() {
        guard let tasks = taskManager?.tasks, !tasks.isEmpty else { return }
        let newId = tasks.first?.id

        Task { @MainActor in
            focusedTaskId = newId
        }
    }

    func selectLast() {
        guard let tasks = taskManager?.tasks, !tasks.isEmpty else { return }
        let newId = tasks.last?.id

        Task { @MainActor in
            focusedTaskId = newId
        }
    }

    func clearFocus() {
        Task { @MainActor in
            focusedTaskId = nil
        }
    }

    func focusedTicket() -> Ticket? {
        guard let id = focusedTaskId,
              let tasks = taskManager?.tasks else { return nil }
        return tasks.first { $0.id == id }
    }
}
