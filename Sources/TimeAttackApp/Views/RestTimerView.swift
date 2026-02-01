import SwiftUI
import TimeAttackCore

struct RestTimerHeader: View {
    let task: SessionTask

    @State private var elapsed: TimeInterval = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var restDuration: TimeInterval {
        task.type.restDuration ?? 0
    }

    private var remaining: TimeInterval {
        restDuration - elapsed
    }

    private var isComplete: Bool {
        remaining <= 0
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(.green)
                    Text("휴식 중")
                        .font(.headline)
                }

                if isComplete {
                    Text("휴식 시간이 끝났습니다!")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("남은 시간")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(formatTime(remaining))
                .font(.system(.title, design: .monospaced))
                .foregroundColor(isComplete ? .orange : .primary)

            HStack(spacing: 8) {
                Button {
                    TimerEngine.shared.startTransitionTask(fromTicketId: nil)
                } label: {
                    Text("작업 시작")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    TimerEngine.shared.endSession()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .onReceive(timer) { _ in
            updateElapsed()
        }
        .onAppear {
            updateElapsed()
        }
    }

    private func updateElapsed() {
        guard !task.isPaused else { return }
        elapsed = Date().timeIntervalSince(task.startTime) - task.totalPausedTime
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let absInterval = abs(interval)
        let minutes = Int(absInterval) / 60
        let seconds = Int(absInterval) % 60

        let sign = interval < 0 ? "+" : ""
        return String(format: "%@%02d:%02d", sign, minutes, seconds)
    }
}
