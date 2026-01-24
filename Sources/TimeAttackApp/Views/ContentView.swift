import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
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
            } else {
                OnboardingView()
            }
        }
    }
}
