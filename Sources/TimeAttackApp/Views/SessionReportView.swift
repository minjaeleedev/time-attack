import SwiftUI
import TimeAttackCore

struct SessionReportView: View {
    let session: Session
    @Binding var isPresented: Bool
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager

    var body: some View {
        VStack(spacing: 20) {
            headerView
            summaryView
            taskBreakdownView
            closeButton
        }
        .padding()
        .frame(width: 400, height: 500)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("세션 완료")
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    private var summaryView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("총 세션 시간")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatDuration(session.totalDuration))
                    .font(.headline)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("작업", systemImage: "hammer.fill")
                        .foregroundColor(.accentColor)
                    Text(formatDuration(session.totalWorkTime))
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Label("휴식", systemImage: "cup.and.saucer.fill")
                        .foregroundColor(.green)
                    Text(formatDuration(session.totalRestTime))
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Label("오버헤드", systemImage: "clock.arrow.2.circlepath")
                        .foregroundColor(.orange)
                    Text(formatDuration(session.totalOverheadTime))
                        .font(.headline)
                }
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private var taskBreakdownView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("작업 상세")
                .font(.headline)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(session.uniqueTicketIds, id: \.self) { ticketId in
                        if let ticket = taskManager.tasks.first(where: { $0.id == ticketId }) {
                            ticketRow(ticket: ticket, ticketId: ticketId)
                        } else {
                            unknownTicketRow(ticketId: ticketId)
                        }
                    }

                    if session.totalRestTime > 0 {
                        restRow
                    }

                    if session.totalDecidingTime > 0 {
                        decidingRow
                    }

                    if session.totalTransitionTime > 0 {
                        transitionRow
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    private func ticketRow(ticket: Ticket, ticketId: String) -> some View {
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

            Text(formatDuration(session.workTimeForTicket(ticketId)))
                .font(.callout)
                .fontWeight(.medium)
        }
        .padding(8)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(6)
    }

    private func unknownTicketRow(ticketId: String) -> some View {
        HStack {
            Text(ticketId)
                .font(.callout)
                .foregroundColor(.secondary)

            Spacer()

            Text(formatDuration(session.workTimeForTicket(ticketId)))
                .font(.callout)
                .fontWeight(.medium)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }

    private var restRow: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(.green)
                Text("휴식")
            }

            Spacer()

            Text(formatDuration(session.totalRestTime))
                .font(.callout)
                .fontWeight(.medium)
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(6)
    }

    private var decidingRow: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.orange)
                Text("결정 시간")
            }

            Spacer()

            Text(formatDuration(session.totalDecidingTime))
                .font(.callout)
                .fontWeight(.medium)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }

    private var transitionRow: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.purple)
                Text("전환 시간")
            }

            Spacer()

            Text(formatDuration(session.totalTransitionTime))
                .font(.callout)
                .fontWeight(.medium)
        }
        .padding(8)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(6)
    }

    private var closeButton: some View {
        Button("닫기") {
            appState.completedSession = nil
            isPresented = false
        }
        .keyboardShortcut(.defaultAction)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%d시간 %02d분", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d분 %02d초", minutes, seconds)
        } else {
            return String(format: "%d초", seconds)
        }
    }
}
