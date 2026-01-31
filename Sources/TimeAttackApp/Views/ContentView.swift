import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if appState.isAuthenticated || taskManager.providerSettings.localEnabled {
                TabView(selection: $selectedTab) {
                    IssueListView()
                        .tabItem {
                            Label("Issues", systemImage: "list.bullet")
                        }
                        .tag(0)

                    ReportView()
                        .tabItem {
                            Label("Reports", systemImage: "chart.bar")
                        }
                        .tag(1)
                }
                .frame(minWidth: 500, minHeight: 400)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Menu {
                            Button(action: {
                                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                            }) {
                                Label("Provider Settings", systemImage: "gear")
                            }
                            Divider()
                            if appState.isAuthenticated {
                                Button(action: {
                                    appState.logout()
                                }) {
                                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .help("Settings")
                    }
                }
            } else {
                OnboardingView()
            }
        }
    }
}
