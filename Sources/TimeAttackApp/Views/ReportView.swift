import SwiftUI

struct ReportView: View {
    @EnvironmentObject var appState: AppState
    
    private var completedSessions: [Session] {
        appState.sessions.filter { $0.endTime != nil }
    }
    
    private var sessionsGroupedByTicket: [(Ticket, [Session])] {
        let grouped = Dictionary(grouping: completedSessions) { $0.ticketId }
        return grouped.compactMap { ticketId, sessions in
            guard let ticket = appState.tickets.first(where: { $0.id == ticketId }) else {
                return nil
            }
            return (ticket, sessions)
        }.sorted { $0.1.first?.startTime ?? Date.distantPast > $1.1.first?.startTime ?? Date.distantPast }
    }
    
    private var weeklyStats: WeeklyStats {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        let weekSessions = completedSessions.filter { session in
            session.startTime >= startOfWeek
        }
        
        let totalTime = weekSessions.reduce(0.0) { $0 + ($1.actualDuration ?? 0) }
        let totalEstimate = weekSessions.reduce(0.0) { total, session in
            guard let ticket = appState.tickets.first(where: { $0.id == session.ticketId }),
                  let estimate = ticket.localEstimate else { return total }
            return total + estimate
        }
        
        let accuracy = totalEstimate > 0 ? totalEstimate / totalTime : 0
        
        return WeeklyStats(
            totalTime: totalTime,
            totalEstimate: totalEstimate,
            accuracy: accuracy,
            sessionCount: weekSessions.count
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WeeklySummaryCard(stats: weeklyStats)
                
                if sessionsGroupedByTicket.isEmpty {
                    ContentUnavailableView(
                        "No completed sessions",
                        systemImage: "clock",
                        description: Text("Start timing your work to see reports here.")
                    )
                } else {
                    Text("By Ticket")
                        .font(.headline)
                    
                    ForEach(sessionsGroupedByTicket, id: \.0.id) { ticket, sessions in
                        TicketReportCard(ticket: ticket, sessions: sessions)
                    }
                }
            }
            .padding()
        }
    }
}

struct WeeklySummaryCard: View {
    let stats: WeeklyStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)
            
            HStack(spacing: 24) {
                StatBox(title: "Time Tracked", value: formatDuration(stats.totalTime))
                StatBox(title: "Sessions", value: "\(stats.sessionCount)")
                StatBox(
                    title: "Accuracy",
                    value: stats.accuracy > 0 ? String(format: "%.0f%%", stats.accuracy * 100) : "-",
                    color: accuracyColor
                )
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var accuracyColor: Color {
        if stats.accuracy == 0 { return .secondary }
        if stats.accuracy >= 0.8 && stats.accuracy <= 1.2 { return .green }
        if stats.accuracy >= 0.5 && stats.accuracy <= 1.5 { return .orange }
        return .red
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct StatBox: View {
    let title: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct TicketReportCard: View {
    let ticket: Ticket
    let sessions: [Session]
    
    private var totalActual: TimeInterval {
        sessions.reduce(0) { $0 + ($1.actualDuration ?? 0) }
    }
    
    private var accuracy: Double? {
        guard let estimate = ticket.localEstimate, estimate > 0 else { return nil }
        return estimate / totalActual
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(ticket.identifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ticket.title)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if let acc = accuracy {
                    Text(String(format: "%.0f%%", acc * 100))
                        .font(.headline)
                        .foregroundColor(accuracyColor(acc))
                }
            }
            
            HStack {
                Label(formatDuration(ticket.localEstimate ?? 0), systemImage: "target")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("→")
                    .foregroundColor(.secondary)
                
                Label(formatDuration(totalActual), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(totalActual > (ticket.localEstimate ?? 0) ? .red : .green)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.8 && accuracy <= 1.2 { return .green }
        if accuracy >= 0.5 && accuracy <= 1.5 { return .orange }
        return .red
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct WeeklyStats {
    let totalTime: TimeInterval
    let totalEstimate: TimeInterval
    let accuracy: Double
    let sessionCount: Int
}
