import Foundation

@MainActor
final class TimerEngine: ObservableObject {
    static let shared = TimerEngine()
    
    private weak var appState: AppState?
    
    private init() {}
    
    func setAppState(_ state: AppState) {
        self.appState = state
        state.sessions = LocalStorage.shared.loadSessions()
    }
    
    func switchTo(ticketId: String) {
        stopSession()
        startSession(ticketId: ticketId)
    }
    
    func startSession(ticketId: String) {
        guard let appState = appState else { return }
        
        let session = Session(ticketId: ticketId)
        appState.activeSession = session
        appState.sessions.append(session)
        saveSessions()
    }
    
    func stopSession() {
        guard let appState = appState,
              var session = appState.activeSession else { return }
        
        if session.isPaused {
            session.pausedIntervals[session.pausedIntervals.count - 1].end = Date()
        }
        
        session.endTime = Date()
        
        if let index = appState.sessions.firstIndex(where: { $0.id == session.id }) {
            appState.sessions[index] = session
        }
        
        appState.activeSession = nil
        saveSessions()
    }
    
    func togglePause() {
        guard let appState = appState,
              var session = appState.activeSession else { return }
        
        if session.isPaused {
            session.pausedIntervals[session.pausedIntervals.count - 1].end = Date()
        } else {
            session.pausedIntervals.append(PausedInterval(start: Date(), end: nil))
        }
        
        appState.activeSession = session
        
        if let index = appState.sessions.firstIndex(where: { $0.id == session.id }) {
            appState.sessions[index] = session
        }
        
        saveSessions()
    }
    
    private func saveSessions() {
        guard let appState = appState else { return }
        LocalStorage.shared.saveSessions(appState.sessions)
    }
}
