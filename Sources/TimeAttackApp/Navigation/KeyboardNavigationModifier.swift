import SwiftUI

struct KeyboardNavigationModifier: ViewModifier {
    @ObservedObject var focusManager: FocusManager
    var onSelect: () -> Void
    var onQuickCreate: () -> Void

    func body(content: Content) -> some View {
        content
            .onKeyPress(.downArrow) {
                focusManager.moveDown()
                return .handled
            }
            .onKeyPress(.upArrow) {
                focusManager.moveUp()
                return .handled
            }
            .onKeyPress("j") {
                focusManager.moveDown()
                return .handled
            }
            .onKeyPress("k") {
                focusManager.moveUp()
                return .handled
            }
            .onKeyPress(.return) {
                if focusManager.focusedTaskId != nil {
                    Task { @MainActor in
                        onSelect()
                    }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress("l") {
                if focusManager.focusedTaskId != nil {
                    Task { @MainActor in
                        onSelect()
                    }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.escape) {
                focusManager.clearFocus()
                return .handled
            }
            .onKeyPress("h") {
                focusManager.clearFocus()
                return .handled
            }
            .onKeyPress("g") {
                focusManager.selectFirst()
                return .handled
            }
            .onKeyPress(keys: ["G"], phases: .down) { _ in
                focusManager.selectLast()
                return .handled
            }
    }
}

extension View {
    func keyboardNavigation(
        focusManager: FocusManager,
        onSelect: @escaping () -> Void,
        onQuickCreate: @escaping () -> Void
    ) -> some View {
        modifier(KeyboardNavigationModifier(
            focusManager: focusManager,
            onSelect: onSelect,
            onQuickCreate: onQuickCreate
        ))
    }
}
