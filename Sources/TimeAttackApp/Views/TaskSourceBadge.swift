import SwiftUI
import TimeAttackCore

struct TaskSourceBadge: View {
    let source: TaskSource

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 10))
            Text(source.providerName)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor.opacity(0.2))
        .foregroundColor(backgroundColor)
        .cornerRadius(4)
        .onTapGesture {
            openExternalUrl()
        }
    }

    private var iconName: String {
        switch source {
        case .local:
            return "folder"
        case .linear:
            return "link"
        case .jira:
            return "ticket"
        }
    }

    private var backgroundColor: Color {
        switch source {
        case .local:
            return .secondary
        case .linear:
            return .purple
        case .jira:
            return .blue
        }
    }

    private func openExternalUrl() {
        guard let url = source.externalUrl else { return }
        NSWorkspace.shared.open(url)
    }
}
