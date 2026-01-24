import SwiftUI

@main
struct TimeAttackApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    setupApp()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.activeSession != nil ? "timer" : "timer.circle")
        }
    }
    
    private func setupApp() {
        TimerEngine.shared.setAppState(appState)
        
        if let token = KeychainManager.shared.getAccessToken() {
            appState.authState = .authenticated(accessToken: token)
            appState.tickets = LocalStorage.shared.loadTickets()
        }
    }
}

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var elapsed: TimeInterval = 0
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let session = appState.activeSession,
               let ticket = appState.tickets.first(where: { $0.id == session.ticketId }) {
                
                Text(ticket.identifier)
                    .font(.headline)
                Text(ticket.title)
                    .font(.caption)
                    .lineLimit(1)
                
                Divider()
                
                HStack {
                    Text(formatTime(remaining(ticket: ticket)))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(remaining(ticket: ticket) < 0 ? .red : .primary)
                    
                    Spacer()
                    
                    Button(session.isPaused ? "Resume" : "Pause") {
                        TimerEngine.shared.togglePause()
                    }
                    
                    Button("Stop") {
                        TimerEngine.shared.stopSession()
                    }
                }
            } else {
                Text("No active timer")
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Button("Open TimeAttack") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            
            Divider()
            
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
        .frame(width: 250)
        .onReceive(timer) { _ in
            updateElapsed()
        }
    }
    
    private func remaining(ticket: Ticket) -> TimeInterval {
        guard let estimate = ticket.localEstimate else { return 0 }
        return estimate - elapsed
    }
    
    private func updateElapsed() {
        guard let session = appState.activeSession, !session.isPaused else { return }
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
}
