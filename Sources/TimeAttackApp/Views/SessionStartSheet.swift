import SwiftUI
import TimeAttackCore

struct SessionStartSheet: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            headerView
            descriptionView
            buttonsView
        }
        .padding()
        .frame(width: 320)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("새 세션 시작")
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    private var descriptionView: some View {
        VStack(spacing: 12) {
            Text("세션을 시작하면 작업 시간을 추적할 수 있습니다.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "hammer.fill", text: "작업별 시간 추적")
                featureRow(icon: "cup.and.saucer.fill", text: "휴식 시간 관리")
                featureRow(icon: "chart.bar.fill", text: "세션 종료 시 리포트")
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.callout)
        }
    }

    private var buttonsView: some View {
        HStack {
            Button("취소") {
                appState.showingSessionStart = false
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("시작") {
                startSession()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
    }

    private func startSession() {
        TimerEngine.shared.startSession()
        appState.showingSessionStart = false
    }
}
