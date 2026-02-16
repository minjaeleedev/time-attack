import SwiftUI
import TimeAttackCore

@main
struct TimeAttackApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var taskManager = TaskManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(taskManager)
                .onAppear {
                    setupApp()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("새 세션") {
                    if appState.currentSession == nil {
                        appState.showingSessionStart = true
                    }
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(appState.currentSession != nil)
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button("전환") {
                    TimerEngine.shared.suspendAndTransition()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(!(appState.activeTask?.type.isWork == true || appState.activeTask?.type.isRest == true))

                Button("세션 종료") {
                    TimerEngine.shared.endSession()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState.currentSession == nil)
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(taskManager)
        } label: {
            Image(systemName: appState.currentSession != nil ? "timer" : "timer.circle")
        }
    }

    private func setupApp() {
        TimerEngine.shared.configure(appState: appState, taskManager: taskManager)

        if let token = KeychainManager.shared.getAccessToken() {
            appState.authState = .authenticated(accessToken: token)
            taskManager.configureLinear(accessToken: token, teamId: appState.selectedTeamId)
        }

        // 활성 세션이 없고 앱 사용 가능하면 세션 시작 모달 표시
        if appState.currentSession == nil {
            let canUseApp = appState.isAuthenticated || taskManager.providerSettings.localEnabled
            if canUseApp {
                appState.showingSessionStart = true
            }
        }
    }
}

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager
    @State private var elapsed: TimeInterval = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let task = appState.activeTask {
                taskContent(task: task)
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

    @ViewBuilder
    private func taskContent(task: SessionTask) -> some View {
        switch task.type {
        case .work(let ticketId):
            if let ticket = taskManager.tasks.first(where: { $0.id == ticketId }) {
                workTaskContent(ticket: ticket, task: task)
            }
        case .rest(let duration):
            restTaskContent(duration: duration, task: task)
        case .deciding:
            decidingContent()
        case .transitioning:
            transitioningContent()
        }
    }

    private func workTaskContent(ticket: Ticket, task: SessionTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ticket.identifier)
                .font(.headline)
            Text(ticket.title)
                .font(.caption)
                .lineLimit(1)

            Divider()

            HStack {
                Text(formatTime(remaining(ticket: ticket, task: task)))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(remaining(ticket: ticket, task: task) < 0 ? .red : .primary)

                Spacer()

                Button(task.isPaused ? "Resume" : "Pause") {
                    TimerEngine.shared.togglePause()
                }

                Button("Stop") {
                    TimerEngine.shared.endSession()
                }
            }
        }
    }

    private func restTaskContent(duration: TimeInterval, task: SessionTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(.green)
                Text("휴식 중")
                    .font(.headline)
            }

            Divider()

            HStack {
                Text(formatTime(duration - elapsed))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(duration - elapsed < 0 ? .orange : .primary)

                Spacer()

                Button("Stop") {
                    TimerEngine.shared.endSession()
                }
            }
        }
    }

    private func decidingContent() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.orange)
                Text("결정 중")
                    .font(.headline)
            }

            Divider()

            HStack {
                Text("다음 할 일을 선택해주세요")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Cancel") {
                    TimerEngine.shared.endSession()
                }
            }
        }
    }

    private func transitioningContent() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.purple)
                Text("전환 중")
                    .font(.headline)
            }

            Divider()

            HStack {
                Text(formatTime(elapsed))
                    .font(.system(.body, design: .monospaced))

                Spacer()

                Button("Cancel") {
                    TimerEngine.shared.endSession()
                }
            }
        }
    }

    private func remaining(ticket: Ticket, task: SessionTask) -> TimeInterval {
        if let initialRemaining = task.initialRemainingTime {
            return initialRemaining - elapsed
        }
        guard let estimate = ticket.localEstimate else { return 0 }
        return estimate - elapsed
    }

    private func updateElapsed() {
        guard let task = appState.activeTask, !task.isPaused else { return }
        elapsed = Date().timeIntervalSince(task.startTime) - task.totalPausedTime
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
