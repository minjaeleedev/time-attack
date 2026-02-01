import SwiftUI
import TimeAttackCore

struct IssueListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager
    @StateObject private var focusManager = FocusManager()

    @State private var showingQuickCreate = false

    var body: some View {
        VStack(spacing: 0) {
            // 활성화된 태스크 헤더 표시
            if let task = appState.activeTask {
                switch task.type {
                case .work(let ticketId):
                    if let ticket = taskManager.tasks.first(where: { $0.id == ticketId }) {
                        ActiveTimerHeader(ticket: ticket, task: task)
                    }
                case .rest:
                    RestTimerHeader(task: task)
                case .deciding:
                    DecidingHeader()
                case .transitioning:
                    TransitioningHeader(task: task)
                }
            }

            content
        }
        .focusable()
        .keyboardNavigation(
            focusManager: focusManager,
            onSelect: handleSelect,
            onQuickCreate: { showingQuickCreate = true }
        )
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    appState.showingSessionStart = true
                } label: {
                    Label("새 세션", systemImage: "plus.circle")
                }
                .disabled(appState.currentSession != nil)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showingQuickCreate = true
                } label: {
                    Label("새 태스크", systemImage: "plus.square")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: refreshTasks) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(taskManager.isLoading)
            }
        }
        .task {
            focusManager.configure(with: taskManager)
            if taskManager.tasks.isEmpty {
                await refreshTasksAsync()
            }
            await loadLinearMetadata()
        }
        .sheet(isPresented: $appState.showingSessionStart) {
            SessionStartSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showingTaskSelection) {
            TaskSelectionSheet()
                .environmentObject(appState)
                .environmentObject(taskManager)
        }
        .sheet(isPresented: $appState.showingTaskSwitch) {
            TaskSwitchModal(isPresented: $appState.showingTaskSwitch)
                .environmentObject(appState)
                .environmentObject(taskManager)
        }
        .sheet(isPresented: showingEstimateSheet) {
            if let ticketId = appState.pendingEstimateTicketId {
                EstimateInputSheet(ticketId: ticketId, isPresented: showingEstimateSheet)
            }
        }
        .sheet(isPresented: $appState.showCreateIssueSheet) {
            CreateIssueSheet()
                .environmentObject(appState)
                .environmentObject(taskManager)
        }
        .sheet(isPresented: $showingQuickCreate) {
            QuickCreateTaskSheet()
                .environmentObject(taskManager)
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showingSessionReport) {
            if let session = appState.completedSession {
                SessionReportView(session: session, isPresented: $appState.showingSessionReport)
                    .environmentObject(appState)
                    .environmentObject(taskManager)
            }
        }
        .alert(
            "작업 완료",
            isPresented: showingCompletionAlert,
            presenting: appState.pendingStateChangeConfirmation
        ) { pending in
            Button("완료로 변경") {
                confirmStateChange(pending)
            }
            Button("취소", role: .cancel) {
                appState.pendingStateChangeConfirmation = nil
            }
        } message: { pending in
            Text("\(pending.ticketIdentifier) 이슈를 '\(pending.targetState.name)' 상태로 변경할까요?")
        }
    }

    private var showingCompletionAlert: Binding<Bool> {
        Binding(
            get: { appState.pendingStateChangeConfirmation != nil },
            set: { if !$0 { appState.pendingStateChangeConfirmation = nil } }
        )
    }

    private func confirmStateChange(_ pending: PendingStateChange) {
        Task {
            if let ticket = taskManager.tasks.first(where: { $0.id == pending.ticketId }) {
                try? await taskManager.updateTaskState(task: ticket, newState: pending.targetState.id)
            }
            appState.pendingStateChangeConfirmation = nil
        }
    }

    private func loadLinearMetadata() async {
        await appState.loadTeams()
        if let teamId = appState.selectedTeamId {
            await appState.loadWorkflowStates(for: teamId)
        }
    }

    private var showingEstimateSheet: Binding<Bool> {
        Binding(
            get: { appState.pendingEstimateTicketId != nil },
            set: { if !$0 { appState.pendingEstimateTicketId = nil } }
        )
    }

    @ViewBuilder
    private var content: some View {
        if taskManager.isLoading && taskManager.tasks.isEmpty {
            ProgressView("Loading tasks...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if taskManager.tasks.isEmpty {
            ContentUnavailableView(
                "No tasks",
                systemImage: "tray",
                description: Text("Press ⌘N to create a local task, or connect Linear for external tasks.")
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(taskManager.tasks) { ticket in
                            IssueRowView(
                                ticket: ticket,
                                isFocused: focusManager.focusedTaskId == ticket.id
                            )
                            .id(ticket.id)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(rowBackground(for: ticket))
                            .onTapGesture {
                                focusManager.focusedTaskId = ticket.id
                            }
                            Divider()
                        }
                    }
                }
                .onChange(of: focusManager.focusedTaskId) { _, newValue in
                    if let id = newValue {
                        withAnimation {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func rowBackground(for ticket: Ticket) -> Color {
        if focusManager.focusedTaskId == ticket.id {
            return Color.accentColor.opacity(0.1)
        }
        return Color.clear
    }

    private func handleSelect() {
        guard let ticket = focusManager.focusedTicket() else { return }

        if ticket.localEstimate == nil {
            appState.pendingEstimateTicketId = ticket.id
        } else {
            TimerEngine.shared.startWorkSession(ticketId: ticket.id)
        }
    }

    @MainActor
    private func refreshTasks() {
        Task {
            await refreshTasksAsync()
        }
    }

    private func refreshTasksAsync() async {
        if let token = appState.accessToken {
            taskManager.configureLinear(accessToken: token, teamId: appState.selectedTeamId)
        }
        await taskManager.refreshAllTasks()
    }
}

// MARK: - DecidingHeader

private struct DecidingHeader: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("결정 중")
                        .font(.headline)
                }
                Text("다음 할 일을 선택해주세요")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                TimerEngine.shared.endSession()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - TransitioningHeader

private struct TransitioningHeader: View {
    let task: SessionTask
    @State private var elapsed: TimeInterval = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.purple)
                    Text("전환 중")
                        .font(.headline)
                }
                Text("전환 시간: \(formatTime(elapsed))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                TimerEngine.shared.endSession()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .onReceive(timer) { _ in
            elapsed = task.actualDuration
        }
        .onAppear {
            elapsed = task.actualDuration
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
