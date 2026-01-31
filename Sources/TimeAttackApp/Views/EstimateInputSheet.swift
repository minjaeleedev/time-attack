import SwiftUI
import TimeAttackCore

struct EstimateInputSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager
    let ticketId: String
    @Binding var isPresented: Bool

    @State private var estimateMinutes: String = ""
    @FocusState private var isFocused: Bool

    private var ticket: Ticket? {
        taskManager.tasks.first { $0.id == ticketId }
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.largeTitle)
                    .foregroundColor(.orange)

                Text("예상 시간 입력")
                    .font(.headline)
            }

            if let ticket = ticket {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(ticket.identifier)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TaskSourceBadge(source: ticket.source)
                    }
                    Text(ticket.title)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("이 작업에 얼마나 걸릴까요?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("30", text: $estimateMinutes)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .focused($isFocused)
                        .onSubmit { saveAndStart() }
                    Text("분")
                }

                HStack(spacing: 8) {
                    ForEach([15, 30, 45, 60], id: \.self) { minutes in
                        Button("\(minutes)분") {
                            estimateMinutes = "\(minutes)"
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            HStack {
                Button("취소") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("시작") {
                    saveAndStart()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canStart)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            isFocused = true
        }
    }

    private var canStart: Bool {
        guard let minutes = Int(estimateMinutes) else { return false }
        return minutes > 0
    }

    private func saveAndStart() {
        guard let minutes = Int(estimateMinutes), minutes > 0 else { return }

        let seconds = TimeInterval(minutes * 60)
        taskManager.updateLocalEstimate(taskId: ticketId, estimate: seconds)

        TimerEngine.shared.startWorkSession(ticketId: ticketId)
        isPresented = false
    }
}
