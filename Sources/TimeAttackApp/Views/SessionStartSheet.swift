import SwiftUI
import TimeAttackCore

struct SessionStartSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager
    @State private var selectedOption: SessionStartOption = .work
    @State private var restMinutes: String = "5"
    @State private var selectedTicketId: String?

    enum SessionStartOption {
        case work
        case rest
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("세션 시작")
                .font(.headline)

            Picker("모드 선택", selection: $selectedOption) {
                Text("작업").tag(SessionStartOption.work)
                Text("휴식").tag(SessionStartOption.rest)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if selectedOption == .work {
                workSelectionView
            } else {
                restSelectionView
            }

            HStack {
                Button("취소") {
                    appState.showingSessionStart = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("시작") {
                    startSession()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canStart)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 320)
    }

    private var workSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("티켓 선택")
                .font(.subheadline)
                .foregroundColor(.secondary)

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
                                isSelected: selectedTicketId == ticket.id
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

    private func startSession() {
        switch selectedOption {
        case .work:
            if let ticketId = selectedTicketId {
                if let ticket = taskManager.tasks.first(where: { $0.id == ticketId }),
                   ticket.localEstimate == nil {
                    appState.pendingEstimateTicketId = ticketId
                } else {
                    TimerEngine.shared.startWorkSession(ticketId: ticketId)
                }
            }
        case .rest:
            if let minutes = Int(restMinutes), minutes > 0 {
                let duration = TimeInterval(minutes * 60)
                TimerEngine.shared.startRestSession(duration: duration)
            }
        }
        appState.showingSessionStart = false
    }
}

private struct TicketSelectionRow: View {
    let ticket: Ticket
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(ticket.identifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TaskSourceBadge(source: ticket.source)
                }
                Text(ticket.title)
                    .lineLimit(1)
                    .font(.callout)
            }

            Spacer()

            if ticket.localEstimate == nil {
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
    }
}
