import SwiftUI
import TimeAttackCore

enum SwitchType {
    case toWork
    case toRest
    case choice
}

struct SessionSwitchModal: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    let switchType: SwitchType
    var currentRemainingTime: TimeInterval?
    var suspendedTicketId: String?

    @State private var selectedOption: SwitchOption = .rest
    @State private var restMinutes: String = "5"
    @State private var selectedTicketId: String?
    @State private var transitionStartTime: Date?
    @State private var transitionElapsed: TimeInterval = 0

    private let transitionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum SwitchOption {
        case rest
        case work
    }

    var body: some View {
        VStack(spacing: 20) {
            headerView

            if transitionStartTime != nil {
                transitionTimeView
            }

            if switchType == .choice {
                Picker("전환 옵션", selection: $selectedOption) {
                    Text("휴식").tag(SwitchOption.rest)
                    Text("다른 작업").tag(SwitchOption.work)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            contentView

            HStack {
                Button("취소") {
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
        .onAppear {
            if switchType == .toWork {
                selectedOption = .work
            } else if switchType == .toRest {
                selectedOption = .rest
            }

            if let remaining = currentRemainingTime, remaining > 0 {
                TimerEngine.shared.suspendCurrentSession(remainingTime: remaining)
                transitionStartTime = Date()
            }
        }
        .onReceive(transitionTimer) { _ in
            if let start = transitionStartTime {
                transitionElapsed = Date().timeIntervalSince(start)
            }
        }
    }

    private var transitionTimeView: some View {
        HStack {
            Image(systemName: "clock.arrow.2.circlepath")
                .foregroundColor(.secondary)
            Text("전환 시간: \(formatTime(transitionElapsed))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var headerView: some View {
        VStack(spacing: 4) {
            Image(systemName: headerIcon)
                .font(.largeTitle)
                .foregroundColor(.accentColor)

            Text(headerTitle)
                .font(.headline)
        }
    }

    private var headerIcon: String {
        switch effectiveOption {
        case .rest: return "cup.and.saucer.fill"
        case .work: return "play.fill"
        }
    }

    private var headerTitle: String {
        switch switchType {
        case .toWork: return "작업 시작"
        case .toRest: return "휴식 시작"
        case .choice: return "세션 전환"
        }
    }

    private var actionButtonTitle: String {
        switch effectiveOption {
        case .rest: return "휴식 시작"
        case .work: return "작업 시작"
        }
    }

    private var effectiveOption: SwitchOption {
        switch switchType {
        case .toWork: return .work
        case .toRest: return .rest
        case .choice: return selectedOption
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch effectiveOption {
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
            Text("티켓 선택")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if appState.tickets.isEmpty {
                Text("할당된 티켓이 없습니다")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.tickets) { ticket in
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
        switch effectiveOption {
        case .rest:
            guard let minutes = Int(restMinutes) else { return false }
            return minutes > 0
        case .work:
            return selectedTicketId != nil
        }
    }

    private func performSwitch() {
        if transitionElapsed > 0 {
            TimerEngine.shared.recordTransitionTime(
                duration: transitionElapsed,
                fromTicketId: suspendedTicketId
            )
        }

        switch effectiveOption {
        case .rest:
            if let minutes = Int(restMinutes), minutes > 0 {
                TimerEngine.shared.switchToRest(duration: TimeInterval(minutes * 60))
            }
        case .work:
            if let ticketId = selectedTicketId {
                if let ticket = appState.tickets.first(where: { $0.id == ticketId }),
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
    var suspendedSession: SuspendedSession? = nil

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
