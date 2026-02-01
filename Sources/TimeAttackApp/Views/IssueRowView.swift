import SwiftUI
import TimeAttackCore

struct IssueRowView: View {
    let ticket: Ticket
    var isFocused: Bool = false

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager

    @State private var estimateInput = ""
    @State private var isEditingEstimate = false

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            ticketInfo
            Spacer()
            estimateSection
            timerButton
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var ticketInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(ticket.identifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                TaskSourceBadge(source: ticket.source)
                StateBadge(state: ticket.state, ticket: ticket)
                if case .none = ticket.dueDateStatus {
                    // no due date badge
                } else {
                    DueDateBadge(status: ticket.dueDateStatus)
                }
            }
            Text(ticket.title)
                .lineLimit(2)
                .fontWeight(isFocused ? .medium : .regular)
        }
    }

    @ViewBuilder
    private var estimateSection: some View {
        if isEditingEstimate {
            HStack {
                TextField("0", text: $estimateInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .focused($isTextFieldFocused)
                    .onSubmit { saveEstimate() }
                    .onExitCommand { isEditingEstimate = false }
                Text("min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onAppear { isTextFieldFocused = true }
        } else {
            Button(action: startEditingEstimate) {
                Text(ticket.displayEstimate)
                    .font(.caption)
                    .foregroundColor(ticket.localEstimate == nil ? .secondary : .primary)
            }
            .buttonStyle(.plain)
        }
    }

    private var timerButton: some View {
        Button(action: toggleTimer) {
            Image(systemName: isActiveTicket ? "stop.fill" : "play.fill")
        }
        .buttonStyle(.borderless)
        .disabled(ticket.localEstimate == nil)
    }

    private var isActiveTicket: Bool {
        appState.activeWorkTicketId == ticket.id
    }

    private func startEditingEstimate() {
        if let estimate = ticket.localEstimate {
            estimateInput = "\(Int(estimate / 60))"
        } else {
            estimateInput = ""
        }
        isEditingEstimate = true
    }

    private func saveEstimate() {
        isEditingEstimate = false

        guard let minutes = Int(estimateInput), minutes > 0 else { return }

        let seconds = TimeInterval(minutes * 60)
        taskManager.updateLocalEstimate(taskId: ticket.id, estimate: seconds)
    }

    private func toggleTimer() {
        if isActiveTicket {
            TimerEngine.shared.endSession()
        } else {
            if ticket.localEstimate == nil {
                appState.pendingEstimateTicketId = ticket.id
            } else {
                TimerEngine.shared.startWorkTask(ticketId: ticket.id)
            }
        }
    }
}

private struct StateBadge: View {
    let state: String
    let ticket: Ticket
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager

    var body: some View {
        if ticket.isLocal {
            localStateMenu
        } else {
            linearStateMenu
        }
    }

    private var localStateMenu: some View {
        Menu {
            ForEach(LocalTaskState.allCases, id: \.self) { taskState in
                Button {
                    changeLocalState(to: taskState)
                } label: {
                    HStack {
                        Text(taskState.displayName)
                        if taskState.displayName == state {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(taskState.displayName == state)
            }
        } label: {
            stateLabel
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var linearStateMenu: some View {
        Menu {
            if appState.workflowStatesForCurrentTeam().isEmpty {
                Text("상태 로딩 중...")
            } else {
                ForEach(appState.workflowStatesForCurrentTeam()) { workflowState in
                    Button {
                        changeLinearState(to: workflowState)
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: workflowState.color))
                                .frame(width: 8, height: 8)
                            Text(workflowState.name)
                            if workflowState.name == state {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(workflowState.name == state)
                }
            }
        } label: {
            stateLabel
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(taskManager.isUpdatingTaskState)
        .onAppear {
            loadStatesIfNeeded()
        }
    }

    private var stateLabel: some View {
        HStack(spacing: 4) {
            Text(state)
                .font(.caption)
            Image(systemName: "chevron.down")
                .font(.system(size: 8))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.2))
        .cornerRadius(4)
    }

    private func loadStatesIfNeeded() {
        guard !ticket.isLocal else { return }
        guard let teamId = appState.selectedTeamId,
              appState.workflowStates[teamId] == nil else { return }

        Task {
            await appState.loadWorkflowStates(for: teamId)
        }
    }

    private func changeLocalState(to newState: LocalTaskState) {
        Task {
            try? await taskManager.updateTaskState(task: ticket, newState: newState.displayName)
        }
    }

    private func changeLinearState(to workflowState: WorkflowState) {
        Task {
            try? await taskManager.updateTaskState(task: ticket, newState: workflowState.id)
        }
    }
}

private struct DueDateBadge: View {
    let status: TicketDueDateStatus

    var body: some View {
        Text(status.displayText)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.2))
            .foregroundColor(badgeColor)
            .cornerRadius(4)
    }

    private var badgeColor: Color {
        switch status.color {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        default: return .secondary
        }
    }
}
