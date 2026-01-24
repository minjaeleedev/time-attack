import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var isAuthenticating = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "timer")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("TimeAttack")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Track your time against estimates.\nLearn to estimate better.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Spacer().frame(height: 20)
            
            Button(action: authenticate) {
                HStack {
                    if isAuthenticating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "link")
                    }
                    Text("Connect to Linear")
                }
                .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAuthenticating)
            
            if case .error(let message) = appState.authState {
                Text(message)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func authenticate() {
        isAuthenticating = true
        appState.authState = .authenticating
        
        Task {
            do {
                let token = try await LinearOAuthClient.shared.authenticate()
                try KeychainManager.shared.saveAccessToken(token)
                appState.authState = .authenticated(accessToken: token)
            } catch {
                appState.authState = .error(error.localizedDescription)
            }
            isAuthenticating = false
        }
    }
}
