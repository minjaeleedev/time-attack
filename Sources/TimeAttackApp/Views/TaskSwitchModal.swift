import SwiftUI
import TimeAttackCore

struct TaskSwitchModal: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager
    @Binding var isPresented: Bool

    @State private var selectedOption: SwitchOption = .work
    @State private var restMinutes: String = "5"
    @State private var selectedTicketId: String?
    @State private var showingCreateTask = false

    enum SwitchOption {
        case rest
        case work
    }

    var body: some View {
        VStack(spacing: 20) {
            headerView

            Picker("전환 옵션", selection: $selectedOption) {
                Text("작업").tag(SwitchOption.work)
                Text("휴식").tag(SwitchOption.rest)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            contentView

            HStack {
                Button("세션 종료") {
                    TimerEngine.shared.endSession()
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(actionButtonTitle) {
                    performSwitch()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSwitch)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 320)
        .sheet(isPresented: $showingCreateTask) {
            CreateIssueSheet()
                .environmentObject(appState)
                .environmentObject(taskManager)
        }
    }

    private var headerView: some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.largeTitle)
                .foregroundColor(.purple)

            Text("다음 태스크 선택")
                .font(.headline)
        }
    }

    private var actionButtonTitle: String {
        switch selectedOption {
        case .rest: return "휴식 시작"
        case .work: return "작업 시작"
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedOption {
        case .rest:
            restInputView
        case .work:
            workSelectionView
        }
    }

    private var restInputView: some View {
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
                            TicketSwitchRow(
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

    private var canSwitch: Bool {
        switch selectedOption {
        case .rest:
            guard let minutes = Int(restMinutes) else { return false }
            return minutes > 0
        case .work:
            return selectedTicketId != nil
        }
    }

    private func performSwitch() {
        switch selectedOption {
        case .rest:
            if let minutes = Int(restMinutes), minutes > 0 {
                TimerEngine.shared.switchToRest(duration: TimeInterval(minutes * 60))
            }
        case .work:
            if let ticketId = selectedTicketId {
                if let ticket = taskManager.tasks.first(where: { $0.id == ticketId }),
                   ticket.localEstimate == nil {
                    appState.pendingEstimateTicketId = ticketId
                } else {
                    TimerEngine.shared.switchToWork(ticketId: ticketId)
                }
            }
        }
        isPresented = false
    }
}

private struct TicketSwitchRow: View {
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
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    private func formatRemainingTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d 남음", minutes, seconds)
    }
}
