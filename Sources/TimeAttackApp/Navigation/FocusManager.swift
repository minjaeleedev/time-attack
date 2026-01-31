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

        if let currentIndex = focusedIndex {
            let newIndex = max(0, currentIndex - 1)
            focusedTaskId = tasks[newIndex].id
        } else {
            focusedTaskId = tasks.first?.id
        }
    }

    func moveDown() {
        guard let tasks = taskManager?.tasks, !tasks.isEmpty else { return }

        if let currentIndex = focusedIndex {
            let newIndex = min(tasks.count - 1, currentIndex + 1)
            focusedTaskId = tasks[newIndex].id
        } else {
            focusedTaskId = tasks.first?.id
        }
    }

    func selectFirst() {
        guard let tasks = taskManager?.tasks, !tasks.isEmpty else { return }
        focusedTaskId = tasks.first?.id
    }

    func selectLast() {
        guard let tasks = taskManager?.tasks, !tasks.isEmpty else { return }
        focusedTaskId = tasks.last?.id
    }

    func clearFocus() {
        focusedTaskId = nil
    }

    func focusedTicket() -> Ticket? {
        guard let id = focusedTaskId,
              let tasks = taskManager?.tasks else { return nil }
        return tasks.first { $0.id == id }
    }
}
