import SwiftUI
import TimeAttackCore

struct IssueListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager
    @StateObject private var focusManager = FocusManager()

    @State private var showingQuickCreate = false

    var body: some View {
        VStack(spacing: 0) {
            if let activeSession = appState.activeSession {
                if activeSession.mode.isRest {
                    RestTimerHeader(session: activeSession)
                } else if let activeTicket = taskManager.tasks.first(where: { $0.id == activeSession.ticketId }) {
                    ActiveTimerHeader(ticket: activeTicket, session: activeSession)
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
                .disabled(appState.activeSession != nil)
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
        .sheet(isPresented: showingEstimateSheet) {
            if let ticketId = appState.pendingEstimateTicketId {
                EstimateInputSheet(ticketId: ticketId, isPresented: showingEstimateSheet)
            }
        }
        .sheet(isPresented: $appState.showCreateIssueSheet) {
            CreateIssueSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingQuickCreate) {
            QuickCreateTaskSheet()
                .environmentObject(taskManager)
                .environmentObject(appState)
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
            _ = await appState.updateIssueState(ticketId: pending.ticketId, stateId: pending.targetState.id)
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
