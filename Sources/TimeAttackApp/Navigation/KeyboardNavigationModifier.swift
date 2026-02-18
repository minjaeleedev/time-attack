import SwiftUI

struct KeyboardNavigationModifier: ViewModifier {
    @ObservedObject var focusManager: FocusManager
    var isEnabled: Bool
    var onSelect: () -> Void
    var onQuickCreate: () -> Void

    func body(content: Content) -> some View {
        content
            .onKeyPress(.downArrow) {
                guard isEnabled else { return .ignored }
                focusManager.moveDown()
                return .handled
            }
            .onKeyPress(.upArrow) {
                guard isEnabled else { return .ignored }
                focusManager.moveUp()
                return .handled
            }
            .onKeyPress("j") {
                guard isEnabled else { return .ignored }
                focusManager.moveDown()
                return .handled
            }
            .onKeyPress("k") {
                guard isEnabled else { return .ignored }
                focusManager.moveUp()
                return .handled
            }
            .onKeyPress(.return) {
                guard isEnabled else { return .ignored }
                if focusManager.focusedTaskId != nil {
                    Task { @MainActor in
                        onSelect()
                    }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress("l") {
                guard isEnabled else { return .ignored }
                if focusManager.focusedTaskId != nil {
                    Task { @MainActor in
                        onSelect()
                    }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.escape) {
                guard isEnabled else { return .ignored }
                focusManager.clearFocus()
                return .handled
            }
            .onKeyPress("h") {
                guard isEnabled else { return .ignored }
                focusManager.clearFocus()
                return .handled
            }
            .onKeyPress("g") {
                guard isEnabled else { return .ignored }
                focusManager.selectFirst()
                return .handled
            }
            .onKeyPress(keys: ["G"], phases: .down) { _ in
                guard isEnabled else { return .ignored }
                focusManager.selectLast()
                return .handled
            }
    }
}

extension View {
    func keyboardNavigation(
        focusManager: FocusManager,
        isEnabled: Bool = true,
        onSelect: @escaping () -> Void,
        onQuickCreate: @escaping () -> Void
    ) -> some View {
        modifier(KeyboardNavigationModifier(
            focusManager: focusManager,
            isEnabled: isEnabled,
            onSelect: onSelect,
            onQuickCreate: onQuickCreate
        ))
    }
}
