import SwiftUI
import TimeAttackCore

struct QuickCreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var appState: AppState

    @State private var title = ""
    @State private var selectedProvider = "Local"
    @State private var isCreating = false
    @State private var errorMessage: String?

    @FocusState private var isTitleFocused: Bool

    private var availableProviders: [String] {
        var providers: [String] = []
        if taskManager.providerSettings.localEnabled {
            providers.append("Local")
        }
        if taskManager.providerSettings.linearEnabled && appState.isAuthenticated {
            providers.append("Linear")
        }
        return providers
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Quick Create Task")
                .font(.headline)

            TextField("Task title", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($isTitleFocused)
                .onSubmit {
                    createTask()
                }

            if availableProviders.count > 1 {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(availableProviders, id: \.self) { provider in
                        HStack {
                            Image(systemName: provider == "Local" ? "folder" : "link")
                            Text(provider)
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Create") {
                    createTask()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            isTitleFocused = true
            if !availableProviders.contains(selectedProvider) {
                selectedProvider = availableProviders.first ?? "Local"
            }
        }
    }

    private func createTask() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let request = TaskCreateRequest(
                    title: title.trimmingCharacters(in: .whitespaces),
                    teamId: selectedProvider == "Linear" ? appState.selectedTeamId : nil
                )

                _ = try await taskManager.createTask(request, providerType: selectedProvider)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}
