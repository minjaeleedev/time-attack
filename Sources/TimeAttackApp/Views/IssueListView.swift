import SwiftUI
import TimeAttackCore

// MARK: - IssueListView
// 이슈 목록을 표시하는 메인 화면
// Linear에서 가져온 티켓들을 리스트로 보여준다
struct IssueListView: View {
    // @EnvironmentObject: 상위 View에서 주입된 공유 상태 객체
    // 앱 전체에서 공유되는 데이터 (티켓 목록, 로그인 상태 등)
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 활성화된 세션 헤더 표시
            if let activeSession = appState.activeSession {
                if activeSession.mode.isRest {
                    RestTimerHeader(session: activeSession)
                } else if let activeTicket = appState.tickets.first(where: { $0.id == activeSession.ticketId }) {
                    ActiveTimerHeader(ticket: activeTicket, session: activeSession)
                }
            }

            // 콘텐츠 영역: 로딩 / 빈 상태 / 목록 중 하나를 표시
            content
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    appState.showingSessionStart = true
                } label: {
                    Label("새 세션", systemImage: "plus.circle")
                }
                .disabled(appState.activeSession != nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: refreshIssues) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(appState.isLoading)
            }
        }
        // .task: View가 나타날 때 비동기 작업 실행
        .task {
            if appState.tickets.isEmpty {
                refreshIssues()
            }
        }
        .sheet(isPresented: $appState.showingSessionStart) {
            SessionStartSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: showingEstimateSheet) {
            if let ticketId = appState.pendingEstimateTicketId {
                EstimateInputSheet(ticketId: ticketId, isPresented: showingEstimateSheet)
            }
        }
    }

    private var showingEstimateSheet: Binding<Bool> {
        Binding(
            get: { appState.pendingEstimateTicketId != nil },
            set: { if !$0 { appState.pendingEstimateTicketId = nil } }
        )
    }

    // MARK: - Content View Builder
    // @ViewBuilder: 여러 View 중 하나를 조건부로 반환할 수 있게 해주는 속성
    @ViewBuilder
    private var content: some View {
        if appState.isLoading && appState.tickets.isEmpty {
            // 로딩 중 + 데이터 없음 → 로딩 인디케이터
            ProgressView("Loading issues...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if appState.tickets.isEmpty {
            // 로딩 완료 + 데이터 없음 → 빈 상태 표시
            ContentUnavailableView(
                "No assigned issues",
                systemImage: "tray",
                description: Text("You have no issues assigned to you in Linear.")
            )
        } else {
            // 데이터 있음 → 이슈 목록 표시
            ScrollView {
                // LazyVStack: 화면에 보이는 항목만 렌더링 (성능 최적화)
                LazyVStack(spacing: 0) {
                    ForEach(appState.tickets) { ticket in
                        IssueRowView(ticket: ticket)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Actions
    // @MainActor: 이 함수가 메인 스레드에서 실행되도록 보장
    // UI 업데이트는 항상 메인 스레드에서 해야 함
    @MainActor
    private func refreshIssues() {
        guard let token = appState.accessToken else { return }
        appState.isLoading = true

        // Task: 비동기 작업을 시작하는 블록
        Task {
            do {
                // try await: 비동기 함수 호출, 실패하면 catch로 이동
                let tickets = try await LinearGraphQLClient.shared.fetchAssignedIssues(accessToken: token)
                appState.tickets = tickets
                LocalStorage.shared.saveTickets(tickets)
            } catch LinearAPIError.unauthorized {
                // 인증 실패 → 로그아웃 처리
                try? KeychainManager.shared.deleteAccessToken()
                appState.authState = .unauthenticated
            } catch {
                // 기타 에러 → 에러 메시지 표시
                appState.errorMessage = error.localizedDescription
            }
            appState.isLoading = false
        }
    }
}
