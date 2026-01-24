import SwiftUI

struct IssueListView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTicketId: String?
    
    var body: some View {
        VStack(spacing: 0) {
            if let activeSession = appState.activeSession,
               let activeTicket = appState.tickets.first(where: { $0.id == activeSession.ticketId }) {
                ActiveTimerHeader(ticket: activeTicket, session: activeSession)
            }
            
            if appState.isLoading && appState.tickets.isEmpty {
                ProgressView("Loading issues...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.tickets.isEmpty {
                ContentUnavailableView(
                    "No assigned issues",
                    systemImage: "tray",
                    description: Text("You have no issues assigned to you in Linear.")
                )
            } else {
                List(appState.tickets, selection: $selectedTicketId) { ticket in
                    IssueRowView(ticket: ticket)
                        .tag(ticket.id)
                }
                .listStyle(.inset)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: refreshIssues) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(appState.isLoading)
            }
        }
        .task {
            await loadIssuesIfNeeded()
        }
    }
    
    private func loadIssuesIfNeeded() async {
        guard appState.tickets.isEmpty else { return }
        refreshIssues()
    }
    
    @MainActor
    private func refreshIssues() {
        guard let token = appState.accessToken else { return }
        appState.isLoading = true
        
        Task {
            do {
                let tickets = try await LinearGraphQLClient.shared.fetchAssignedIssues(accessToken: token)
                appState.tickets = tickets
                LocalStorage.shared.saveTickets(tickets)
            } catch {
                appState.errorMessage = error.localizedDescription
            }
            appState.isLoading = false
        }
    }
}

struct IssueRowView: View {
    let ticket: Ticket
    @EnvironmentObject var appState: AppState
    @State private var estimateInput = ""
    @State private var isEditingEstimate = false
    @FocusState private var isEstimateFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ticket.identifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ticket.state)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                Text(ticket.title)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isEditingEstimate {
                HStack {
                    TextField("0m", text: $estimateInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .focused($isEstimateFocused)
                        .onSubmit(saveEstimate)
                    Text("min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: startEditingEstimate) {
                    Text(ticket.displayEstimate)
                        .font(.caption)
                        .foregroundColor(ticket.localEstimate == nil ? .secondary : .primary)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: startTimer) {
                Image(systemName: isActiveTicket ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.borderless)
            .disabled(ticket.localEstimate == nil)
        }
        .padding(.vertical, 4)
    }
    
    private var isActiveTicket: Bool {
        appState.activeSession?.ticketId == ticket.id
    }
    
    private func startEditingEstimate() {
        if let estimate = ticket.localEstimate {
            estimateInput = "\(Int(estimate / 60))"
        } else {
            estimateInput = ""
        }
        isEditingEstimate = true
        isEstimateFocused = true
    }
    
    private func saveEstimate() {
        isEditingEstimate = false
        guard let minutes = Int(estimateInput), minutes > 0 else { return }
        let seconds = TimeInterval(minutes * 60)
        
        if let index = appState.tickets.firstIndex(where: { $0.id == ticket.id }) {
            appState.tickets[index].localEstimate = seconds
            LocalStorage.shared.saveEstimate(ticketId: ticket.id, estimate: seconds)
            LocalStorage.shared.saveTickets(appState.tickets)
        }
    }
    
    private func startTimer() {
        if isActiveTicket {
            TimerEngine.shared.stopSession()
        } else {
            TimerEngine.shared.switchTo(ticketId: ticket.id)
        }
    }
}

struct ActiveTimerHeader: View {
    let ticket: Ticket
    let session: Session
    @State private var elapsed: TimeInterval = 0
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(ticket.identifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(ticket.title)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(formatTime(remaining))
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(remaining < 0 ? .red : .primary)
                
                if let estimate = ticket.localEstimate {
                    ProgressView(value: min(elapsed / estimate, 1.0))
                        .frame(width: 100)
                        .tint(remaining < 0 ? .red : .accentColor)
                }
            }
            
            HStack(spacing: 8) {
                Button(action: togglePause) {
                    Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.borderless)
                
                Button(action: stop) {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .onReceive(timer) { _ in
            updateElapsed()
        }
        .onAppear {
            updateElapsed()
        }
    }
    
    private var remaining: TimeInterval {
        guard let estimate = ticket.localEstimate else { return 0 }
        return estimate - elapsed
    }
    
    private func updateElapsed() {
        guard !session.isPaused else { return }
        elapsed = Date().timeIntervalSince(session.startTime) - session.totalPausedTime
    }
    
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
    
    private func togglePause() {
        TimerEngine.shared.togglePause()
    }
    
    private func stop() {
        TimerEngine.shared.stopSession()
    }
}
