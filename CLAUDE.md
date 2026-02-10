# TimeAttack - macOS 시간 추적 앱

이 프로젝트는 Swift로 작성된 macOS 전용 시간 추적 애플리케이션입니다.
- SwiftUI 기반 UI
- Linear 및 로컬 작업 관리 지원
- 최소 macOS 14.0 요구

## 개발 환경 설정

### 필수 요구사항
- Xcode 16.0+
- Swift 5.9+
- macOS 14.0+

### 빌드 및 실행
```bash
# Swift Package Manager로 빌드
swift build

# 또는 run.sh 스크립트 사용 (앱 번들 생성 및 실행)
./run.sh
```

### 테스트 실행
```bash
swift test
```

### 프로젝트 구조
- `Sources/TimeAttackCore/`: 핵심 비즈니스 로직 (Framework)
- `Sources/TimeAttackApp/`: SwiftUI 앱 코드 (Application)
- `Tests/TimeAttackTests/`: 단위 테스트

## 코딩 규칙

### 언어
- UI 텍스트는 한국어 사용 (예: "새 이슈 생성", "티켓 선택")
- 코드 및 주석은 영어 사용
- Git 커밋 메시지는 영어 사용 (conventional commits 형식)

### SwiftUI 패턴
- `@EnvironmentObject`로 `AppState`, `TaskManager` 공유
- Private computed properties로 뷰 컴포넌트 분리 (`private var header: some View`)
- `@State` + `@FocusState` 활용한 폼 상태 관리
- Validation 로직은 computed property로 분리 (`private var canCreate: Bool`)

예시 (CreateIssueSheet.swift:240-244):
```swift
private var canCreate: Bool {
    let hasTitle = !title.trimmingCharacters(in: .whitespaces).isEmpty
    let hasTeamIfNeeded = selectedProvider == "Local" || appState.selectedTeamId != nil
    return hasTitle && hasTeamIfNeeded && !taskManager.isCreatingTask
}
```

### 에러 핸들링
- `AppState.errorMessage`에 에러 메시지 저장
- `.alert` modifier로 일관된 에러 표시
- 비동기 작업에서 발생한 에러는 `error.localizedDescription` 사용

예시 (CreateIssueSheet.swift:54-58):
```swift
.alert("오류", isPresented: showingError) {
    Button("확인") { appState.errorMessage = nil }
} message: {
    Text(appState.errorMessage ?? "")
}
```

### 비동기 작업
- Swift Concurrency (`async/await`) 사용
- UI 업데이트가 필요한 비동기 작업은 `Task { }` 블록 사용
- 로딩 상태 표시 (예: `ProgressView` + "로딩 중..." 텍스트)

## 프로바이더 시스템

### 지원하는 프로바이더
1. **Local**: 로컬 작업 저장 (항상 사용 가능)
2. **Linear**: Linear API 연동 (인증 필요)

### 프로바이더별 차이점
- **Local 작업**:
  - `estimate` 필드 지원 (분 단위)
  - 팀 선택 불필요

- **Linear 작업**:
  - `estimate` 필드를 전송하면 400 에러 발생 → 전송하지 않음
  - `teamId` 필수
  - 팀 및 workflow states 로딩 필요

### 프로바이더별 분기 처리 패턴
프로바이더에 따라 다른 필드를 전송해야 할 때는 조건부 할당을 사용합니다 (CreateIssueSheet.swift:253-255):

```swift
// Local tasks use estimate in minutes, Linear doesn't accept estimate (400 error)
let estimate = selectedProvider == "Local" ? Int(estimateMinutes) : nil
let teamId = selectedProvider == "Linear" ? appState.selectedTeamId : nil
```

### 새 이슈 생성 시 검증 규칙
- 제목 필수 (`!title.trimmingCharacters(in: .whitespaces).isEmpty`)
- Local: 팀 선택 불필요
- Linear: `appState.selectedTeamId` 필수
- 생성 중일 때 (`taskManager.isCreatingTask`) 중복 생성 방지

### 초기화 패턴
- `onAppear`에서 기본값 설정 (`initializeDefaultProvider()`)
- `onChange`로 프로바이더 변경 감지 및 관련 데이터 로딩

예시 (CreateIssueSheet.swift:45-53):
```swift
.onAppear {
    titleFocused = true
    initializeDefaultProvider()
}
.onChange(of: selectedProvider) { _, newValue in
    if newValue == "Linear" {
        loadLinearTeamsIfNeeded()
    }
}
```

## Pull Request 작성

### PR 템플릿 준수
- `.github/PULL_REQUEST_TEMPLATE.md` 참조
- Summary, Key Features, Test Plan 섹션 필수 작성
- 타입별 접두사 사용: `feat:`, `fix:`, `refactor:`, `chore:`

### 필수 테스트 항목
- [ ] Xcode 빌드 성공
- [ ] `swift test` 통과
- [ ] 주요 기능 수동 검증
- [ ] Edge case 테스트

### 변경사항 설명
- **feat**: 사용자에게 보이는 기능 설명
- **fix**: 무엇이 고장났고 어떻게 고쳤는지 설명
- **refactor**: 왜 리팩토링이 코드베이스를 개선하는지 설명

## 알려진 제약사항 및 특이사항

### 빌드 시스템
- Swift Package Manager 사용
- `run.sh` 스크립트가 앱 번들 구조를 수동으로 생성
- XcodeGen (`project.yml`) 설정도 존재하지만 주로 SPM 사용

### 의존성
- KeychainAccess 4.2.2+: 인증 토큰 저장용

### 키보드 단축키
- TaskSelectionSheet에서 vim 스타일 단축키 지원:
  - `j` / `down`: 아래로 이동
  - `k` / `up`: 위로 이동
  - `Cmd+N`: 새 티켓 생성

### Linear API 제약사항
- Linear는 `estimate` 필드를 받지 않음 (400 error)
- 향후 다른 Linear API 호출 시 주의 필요
- 팀 및 workflow states는 별도로 로딩해야 함
