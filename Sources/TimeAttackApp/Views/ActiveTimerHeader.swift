import SwiftUI
import TimeAttackCore

// MARK: - ActiveTimerHeader
// 타이머가 실행 중일 때 화면 상단에 표시되는 헤더
// 현재 작업 중인 티켓 정보, 남은 시간, 일시정지/정지 버튼 포함
struct ActiveTimerHeader: View {
    let ticket: Ticket
    let session: Session

    // @State: View 내부 상태 - 경과 시간을 추적
    @State private var elapsed: TimeInterval = 0
    @State private var showingSessionSwitch = false

    // Timer.publish: 1초마다 이벤트를 발생시키는 타이머
    // autoconnect(): 자동으로 타이머 시작
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            ticketInfo
            Spacer()
            timerDisplay
            controlButtons
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        // .onReceive: Publisher(타이머)로부터 이벤트를 받을 때마다 실행
        .onReceive(timer) { _ in
            updateElapsed()
        }
        .onAppear {
            updateElapsed()
        }
        .sheet(isPresented: $showingSessionSwitch) {
            SessionSwitchModal(
                isPresented: $showingSessionSwitch,
                switchType: .choice,
                currentRemainingTime: remaining,
                suspendedTicketId: session.ticketId
            )
        }
    }

    // MARK: - Subviews

    private var ticketInfo: some View {
        VStack(alignment: .leading) {
            Text(ticket.identifier)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(ticket.title)
                .lineLimit(1)
        }
    }

    private var timerDisplay: some View {
        VStack(alignment: .trailing) {
            // 남은 시간 표시 (초과하면 빨간색)
            Text(formatTime(remaining))
                .font(.system(.title2, design: .monospaced))
                .foregroundColor(remaining < 0 ? .red : .primary)

            // 진행률 바
            if let estimate = ticket.localEstimate {
                ProgressView(value: min(elapsed / estimate, 1.0))
                    .frame(width: 100)
                    .tint(remaining < 0 ? .red : .accentColor)
            }
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 8) {
            // 일시정지 버튼 - 모달 표시
            Button(action: {
                showingSessionSwitch = true
            }) {
                Image(systemName: "pause.fill")
            }
            .buttonStyle(.borderless)

            // 정지 버튼
            Button(action: { TimerEngine.shared.stopSession() }) {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Computed Properties

    // 남은 시간 = 예상 시간 - 경과 시간
    // 재개된 세션의 경우 initialRemainingTime 사용
    private var remaining: TimeInterval {
        if let initialRemaining = session.initialRemainingTime {
            return initialRemaining - elapsed
        }
        guard let estimate = ticket.localEstimate else { return 0 }
        return estimate - elapsed
    }

    // MARK: - Methods

    private func updateElapsed() {
        // 일시정지 상태면 업데이트 안 함
        guard !session.isPaused else { return }
        // 경과 시간 = 현재 시간 - 시작 시간 - 일시정지된 총 시간
        elapsed = Date().timeIntervalSince(session.startTime) - session.totalPausedTime
    }

    // 시간을 "MM:SS" 또는 "H:MM:SS" 형식으로 변환
    private func formatTime(_ interval: TimeInterval) -> String {
        let absInterval = abs(interval)
        let hours = Int(absInterval) / 3600
        let minutes = (Int(absInterval) % 3600) / 60
        let seconds = Int(absInterval) % 60

        let sign = interval < 0 ? "-" : ""
        if hours > 0 {
            return String(format: "%@%d:%02d:%02d", sign, hours, minutes, seconds)
        }
        return String(format: "%@%02d:%02d", sign, minutes, seconds)
    }
}
