import SwiftUI
import TimeAttackCore

struct ProviderSettingsView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Task Providers") {
                Toggle(isOn: localEnabledBinding) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading) {
                            Text("Local Tasks")
                            Text("Create and manage tasks locally without external services")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Toggle(isOn: linearEnabledBinding) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text("Linear")
                            if appState.isAuthenticated {
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Not connected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .disabled(!appState.isAuthenticated)

                if !appState.isAuthenticated {
                    Button("Connect Linear Account") {
                        // Trigger OAuth flow
                    }
                    .disabled(true) // TODO: Implement OAuth trigger
                } else {
                    Button("Disconnect Linear") {
                        appState.logout()
                    }
                    .foregroundColor(.red)
                }
            }

            Section("About") {
                HStack {
                    Text("Local Tasks")
                    Spacer()
                    Text("\(taskManager.localTasks.count)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Linear Tasks")
                    Spacer()
                    Text("\(taskManager.linearTasks.count)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }

    private var localEnabledBinding: Binding<Bool> {
        Binding(
            get: { taskManager.providerSettings.localEnabled },
            set: { newValue in
                var settings = taskManager.providerSettings
                settings.localEnabled = newValue
                taskManager.updateProviderSettings(settings)
            }
        )
    }

    private var linearEnabledBinding: Binding<Bool> {
        Binding(
            get: { taskManager.providerSettings.linearEnabled },
            set: { newValue in
                var settings = taskManager.providerSettings
                settings.linearEnabled = newValue
                taskManager.updateProviderSettings(settings)
            }
        )
    }
}
