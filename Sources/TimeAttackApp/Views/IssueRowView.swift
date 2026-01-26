import SwiftUI
import TimeAttackCore

// MARK: - IssueRowView
// 개별 이슈(티켓)를 한 줄로 표시하는 컴포넌트
// [티켓 정보] [예상 시간 입력] [타이머 시작/정지 버튼] 구조
struct IssueRowView: View {
    // 이 View에 전달되는 티켓 데이터 (불변)
    let ticket: Ticket

    // 앱 전체 상태 (티켓 목록 수정, 타이머 상태 확인에 사용)
    @EnvironmentObject var appState: AppState

    // @State: 이 View 내부에서만 사용하는 상태
    // View가 다시 그려져도 값이 유지됨
    @State private var estimateInput = ""
    @State private var isEditingEstimate = false

    // @FocusState: 키보드 포커스를 관리하는 특수 상태
    // TextField에 자동으로 포커스를 주기 위해 사용
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            ticketInfo
            Spacer()
            estimateSection
            timerButton
        }
        .padding(.vertical, 4)
    }

    // MARK: - Subviews

    // 티켓 기본 정보 (식별자, 상태, 마감일, 제목)
    private var ticketInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(ticket.identifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                StateBadge(state: ticket.state, ticketId: ticket.id)
                if case .none = ticket.dueDateStatus {
                    // no due date badge
                } else {
                    DueDateBadge(status: ticket.dueDateStatus)
                }
            }
            Text(ticket.title)
                .lineLimit(2)
        }
    }

    // 예상 시간 표시/편집 영역
    @ViewBuilder
    private var estimateSection: some View {
        if isEditingEstimate {
            // 편집 모드: TextField 표시
            HStack {
                TextField("0", text: $estimateInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .focused($isFocused)           // 포커스 상태 바인딩
                    .onSubmit { saveEstimate() }   // Enter 키 → 저장
                    .onExitCommand { isEditingEstimate = false }  // Esc 키 → 취소
                Text("min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onAppear { isFocused = true }  // 나타날 때 자동 포커스
        } else {
            // 표시 모드: 버튼으로 표시 (클릭하면 편집 모드로)
            Button(action: startEditingEstimate) {
                Text(ticket.displayEstimate)
                    .font(.caption)
                    .foregroundColor(ticket.localEstimate == nil ? .secondary : .primary)
            }
            .buttonStyle(.plain)
        }
    }

    // 타이머 시작/정지 버튼
    private var timerButton: some View {
        Button(action: toggleTimer) {
            Image(systemName: isActiveTicket ? "stop.fill" : "play.fill")
        }
        .buttonStyle(.borderless)
        .disabled(ticket.localEstimate == nil)  // 예상 시간 없으면 비활성화
    }

    // MARK: - Computed Properties

    // 현재 이 티켓의 타이머가 실행 중인지 확인
    private var isActiveTicket: Bool {
        appState.activeSession?.ticketId == ticket.id
    }

    // MARK: - Actions

    private func startEditingEstimate() {
        // 기존 예상 시간이 있으면 분 단위로 변환해서 표시
        if let estimate = ticket.localEstimate {
            estimateInput = "\(Int(estimate / 60))"
        } else {
            estimateInput = ""
        }
        isEditingEstimate = true
    }

    private func saveEstimate() {
        isEditingEstimate = false

        // guard: 조건이 거짓이면 함수 종료 (early return 패턴)
        guard let minutes = Int(estimateInput), minutes > 0 else { return }

        let seconds = TimeInterval(minutes * 60)

        // 티켓 목록에서 현재 티켓을 찾아 예상 시간 업데이트
        if let index = appState.tickets.firstIndex(where: { $0.id == ticket.id }) {
            appState.tickets[index].localEstimate = seconds
            LocalStorage.shared.saveEstimate(ticketId: ticket.id, estimate: seconds)
            LocalStorage.shared.saveTickets(appState.tickets)
        }
    }

    private func toggleTimer() {
        if isActiveTicket {
            TimerEngine.shared.stopSession()
        } else {
            // Check if estimate is needed first
            if ticket.localEstimate == nil {
                appState.pendingEstimateTicketId = ticket.id
            } else {
                TimerEngine.shared.startWorkSession(ticketId: ticket.id)
            }
        }
    }
}

// MARK: - StateBadge
// 티켓 상태를 뱃지 형태로 표시하는 작은 컴포넌트
// 탭하면 상태 변경 메뉴가 표시됨
private struct StateBadge: View {
    let state: String
    let ticketId: String
    @EnvironmentObject var appState: AppState

    var body: some View {
        Menu {
            if appState.workflowStatesForCurrentTeam().isEmpty {
                Text("상태 로딩 중...")
            } else {
                ForEach(appState.workflowStatesForCurrentTeam()) { workflowState in
                    Button {
                        changeState(to: workflowState)
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
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(appState.isUpdatingIssueState)
        .onAppear {
            loadStatesIfNeeded()
        }
    }

    private func loadStatesIfNeeded() {
        guard let teamId = appState.selectedTeamId,
              appState.workflowStates[teamId] == nil else { return }

        Task {
            await appState.loadWorkflowStates(for: teamId)
        }
    }

    private func changeState(to workflowState: WorkflowState) {
        Task {
            _ = await appState.updateIssueState(ticketId: ticketId, stateId: workflowState.id)
        }
    }
}

// MARK: - DueDateBadge
// 마감일 상태를 뱃지 형태로 표시하는 컴포넌트
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
