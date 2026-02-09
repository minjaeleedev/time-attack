import SwiftUI
import TimeAttackCore

struct TaskSelectionSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager
    @State private var selectedOption: TaskOption = .work
    @State private var restMinutes: String = "5"
    @State private var selectedTicketId: String?
    @State private var elapsedTime: TimeInterval = 0
    @State private var showingCreateTask = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let startTime = Date()

    enum TaskOption {
        case work
        case rest
    }

    var body: some View {
        VStack(spacing: 20) {
            headerView

            Picker("모드 선택", selection: $selectedOption) {
                Text("작업").tag(TaskOption.work)
                Text("휴식").tag(TaskOption.rest)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if selectedOption == .work {
                workSelectionView
            } else {
                restSelectionView
            }

            HStack {
                Button("세션 종료") {
                    TimerEngine.shared.endSession()
                    appState.showingTaskSelection = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("시작") {
                    startTask()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canStart)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 320)
        .onReceive(timer) { _ in
            elapsedTime = Date().timeIntervalSince(startTime)
        }
        .sheet(isPresented: $showingCreateTask) {
            CreateIssueSheet()
                .environmentObject(appState)
                .environmentObject(taskManager)
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress("k") {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress("j") {
            moveSelection(by: 1)
            return .handled
        }
    }

    private var headerView: some View {
        VStack(spacing: 4) {
            Image(systemName: "questionmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("다음 할 일 선택")
                .font(.headline)

            Text(formatElapsedTime(elapsedTime))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func formatElapsedTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "선택 시간: %02d:%02d", minutes, seconds)
    }

    private var workSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("티켓 선택")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    showingCreateTask = true
                } label: {
                    Label("새 티켓", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("n", modifiers: .command)
            }

            if taskManager.tasks.isEmpty {
                Text("할당된 티켓이 없습니다")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(taskManager.tasks) { ticket in
                            TicketSelectionRow(
                                ticket: ticket,
                                isSelected: selectedTicketId == ticket.id,
                                suspendedSession: appState.suspendedSessions[ticket.id]
                            )
                            .onTapGesture {
                                selectedTicketId = ticket.id
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private var restSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("휴식 시간")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                TextField("5", text: $restMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                Text("분")
            }

            HStack(spacing: 8) {
                ForEach([5, 10, 15, 30], id: \.self) { minutes in
                    Button("\(minutes)분") {
                        restMinutes = "\(minutes)"
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var canStart: Bool {
        switch selectedOption {
        case .work:
            return selectedTicketId != nil
        case .rest:
            guard let minutes = Int(restMinutes) else { return false }
            return minutes > 0
        }
    }

    private func startTask() {
        switch selectedOption {
        case .work:
            if let ticketId = selectedTicketId {
                if let ticket = taskManager.tasks.first(where: { $0.id == ticketId }),
                   ticket.localEstimate == nil {
                    appState.pendingEstimateTicketId = ticketId
                } else {
                    TimerEngine.shared.startWorkTask(ticketId: ticketId)
                }
            }
        case .rest:
            if let minutes = Int(restMinutes), minutes > 0 {
                let duration = TimeInterval(minutes * 60)
                TimerEngine.shared.startRestSession(duration: duration)
            }
        }
        appState.showingTaskSelection = false
    }

    private func moveSelection(by offset: Int) {
        guard selectedOption == .work else { return }
        let tasks = taskManager.tasks
        guard !tasks.isEmpty else { return }

        if let currentId = selectedTicketId,
           let currentIndex = tasks.firstIndex(where: { $0.id == currentId }) {
            let newIndex = max(0, min(tasks.count - 1, currentIndex + offset))
            selectedTicketId = tasks[newIndex].id
        } else {
            selectedTicketId = tasks.first?.id
        }
    }
}

private struct TicketSelectionRow: View {
    let ticket: Ticket
    let isSelected: Bool
    var suspendedSession: SuspendedSession?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.identifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(ticket.title)
                    .lineLimit(1)
                    .font(.callout)
            }

            Spacer()

            if let suspended = suspendedSession {
                Label(formatRemainingTime(suspended.remainingTime), systemImage: "pause.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            } else if ticket.localEstimate == nil {
                Text("예상 시간 필요")
                    .font(.caption2)
                    .foregroundColor(.orange)
            } else {
                Text(ticket.displayEstimate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }

    private func formatRemainingTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d 남음", minutes, seconds)
    }
}
