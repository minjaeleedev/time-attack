import SwiftUI
import TimeAttackCore

struct CreateIssueSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var selectedPriority: Int = 0
    @State private var estimateMinutes = ""

    @FocusState private var titleFocused: Bool

    private let priorities = [
        (value: 0, label: "우선순위 없음"),
        (value: 1, label: "긴급"),
        (value: 2, label: "높음"),
        (value: 3, label: "보통"),
        (value: 4, label: "낮음")
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(width: 400, height: 480)
        .onAppear {
            titleFocused = true
            Task {
                await appState.loadTeams()
                if let teamId = appState.selectedTeamId {
                    await appState.loadWorkflowStates(for: teamId)
                }
            }
        }
        .alert("오류", isPresented: showingError) {
            Button("확인") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            Text("새 이슈 생성")
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                teamPicker
                titleField
                descriptionField
                priorityPicker
                estimateField
            }
            .padding()
        }
    }

    private var teamPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("팀")
                .font(.caption)
                .foregroundColor(.secondary)

            if appState.teams.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("팀 목록 로딩 중...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Picker("팀", selection: $appState.selectedTeamId) {
                    ForEach(appState.teams) { team in
                        Text(team.name).tag(team.id as String?)
                    }
                }
                .labelsHidden()
                .onChange(of: appState.selectedTeamId) { _, newValue in
                    if let teamId = newValue {
                        Task {
                            await appState.loadWorkflowStates(for: teamId)
                        }
                    }
                }
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("제목")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("*")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            TextField("이슈 제목을 입력하세요", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("설명")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $description)
                .font(.body)
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private var priorityPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("우선순위")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("우선순위", selection: $selectedPriority) {
                ForEach(priorities, id: \.value) { priority in
                    HStack {
                        if priority.value > 0 {
                            PriorityIcon(priority: priority.value)
                        }
                        Text(priority.label)
                    }
                    .tag(priority.value)
                }
            }
            .labelsHidden()
        }
    }

    private var estimateField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("예상 시간 (분)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                TextField("30", text: $estimateMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("분")
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    ForEach([15, 30, 60], id: \.self) { minutes in
                        Button("\(minutes)") {
                            estimateMinutes = "\(minutes)"
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("취소") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("생성") {
                createIssue()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canCreate)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        appState.selectedTeamId != nil &&
        !taskManager.isCreatingTask
    }

    private func createIssue() {
        guard let teamId = appState.selectedTeamId,
              !taskManager.isCreatingTask else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        let priority = selectedPriority > 0 ? selectedPriority : nil
        let estimate = Int(estimateMinutes)

        Task {
            do {
                let request = TaskCreateRequest(
                    title: trimmedTitle,
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    priority: priority,
                    estimate: estimate,
                    teamId: teamId
                )
                _ = try await taskManager.createTask(request, providerType: "Linear")
                dismiss()
            } catch {
                appState.errorMessage = error.localizedDescription
            }
        }
    }

    private var showingError: Binding<Bool> {
        Binding(
            get: { appState.errorMessage != nil && !taskManager.isCreatingTask },
            set: { if !$0 { appState.errorMessage = nil } }
        )
    }
}

private struct PriorityIcon: View {
    let priority: Int

    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
            .font(.caption)
    }

    private var iconName: String {
        switch priority {
        case 1: return "exclamationmark.triangle.fill"
        case 2: return "arrow.up"
        case 3: return "minus"
        case 4: return "arrow.down"
        default: return "minus"
        }
    }

    private var iconColor: Color {
        switch priority {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .blue
        default: return .secondary
        }
    }
}
