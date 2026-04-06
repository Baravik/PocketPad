// KeyboardInputView.swift
// PocketPadIOS
// Keyboard mode with text input, special keys, and shortcut toolbar

import SwiftUI

struct KeyboardInputView: View {
    @EnvironmentObject var viewModel: TrackpadViewModel
    @State private var inputText = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Modifier toolbar
            modifierToolbar

            Divider()

            // Shortcut bar
            shortcutBar

            Divider()

            // Text input area
            HStack(spacing: 8) {
                // Custom text field that captures delete on empty
                DeleteAwareTextField(
                    text: $inputText,
                    placeholder: "Type here…",
                    onTextChange: { newValue in
                        if !newValue.isEmpty {
                            viewModel.sendText(newValue)
                            inputText = ""
                        }
                    },
                    onDelete: {
                        viewModel.sendSpecialKey(.delete)
                    },
                    onReturn: {
                        viewModel.sendSpecialKey(.enter)
                    }
                )
                .frame(height: 40)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )

                // Send button
                Button {
                    viewModel.sendSpecialKey(.enter)
                } label: {
                    Image(systemName: "return")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Special keys row
            specialKeysRow

            // Drag handle + Hide Keyboard button
            VStack(spacing: 4) {
                // Drag handle indicator
                Capsule()
                    .fill(Color(.systemGray3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 6)

                Button {
                    dismissKeyboard()
                } label: {
                    HStack {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.subheadline)
                        Text("Hide Keyboard")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(.ultraThinMaterial)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    // Swipe down to dismiss
                    if value.translation.height > 50 {
                        dismissKeyboard()
                    }
                }
        )
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        viewModel.showKeyboard = false
    }

    // MARK: - Modifier Toolbar

    private var modifierToolbar: some View {
        HStack(spacing: 8) {
            modifierButton("⌘", label: "Cmd", isActive: $viewModel.commandActive)
            modifierButton("⌥", label: "Opt", isActive: $viewModel.optionActive)
            modifierButton("⌃", label: "Ctrl", isActive: $viewModel.controlActive)
            modifierButton("⇧", label: "Shift", isActive: $viewModel.shiftActive)

            Spacer()

            // Escape key
            Button {
                viewModel.sendSpecialKey(.escape)
            } label: {
                Text("Esc")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func modifierButton(_ symbol: String, label: String, isActive: Binding<Bool>) -> some View {
        Button {
            isActive.wrappedValue.toggle()
        } label: {
            VStack(spacing: 1) {
                Text(symbol)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.system(size: 8))
            }
            .frame(width: 50, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive.wrappedValue ? Color.accentColor : Color(.systemGray5))
            )
            .foregroundColor(isActive.wrappedValue ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shortcut Bar

    private var shortcutBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                shortcutPill("Cmd-C", key: "c", mod: .command)
                shortcutPill("Cmd-V", key: "v", mod: .command)
                shortcutPill("Cmd-X", key: "x", mod: .command)
                shortcutPill("Cmd-Z", key: "z", mod: .command)
                shortcutPill("Cmd-A", key: "a", mod: .command)
                shortcutPill("Cmd-S", key: "s", mod: .command)
                shortcutPill("Cmd-Tab", key: "\t", mod: .command)
                shortcutPill("Cmd-Space", key: " ", mod: .command) // Spotlight
                shortcutPill("Cmd-W", key: "w", mod: .command)
                shortcutPill("Cmd-Q", key: "q", mod: .command)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func shortcutPill(_ label: String, key: String, mod: ModifierFlags) -> some View {
        Button {
            viewModel.sendShortcut(key: key, modifiers: mod)
        } label: {
            Text(label)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color(.systemGray5))
                )
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Special Keys Row

    private var specialKeysRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                specialKeyButton("Tab", key: .tab)
                specialKeyButton("⌫", key: .delete)
                specialKeyButton("⌦", key: .forwardDelete)
                specialKeyButton("←", key: .arrowLeft)
                specialKeyButton("→", key: .arrowRight)
                specialKeyButton("↑", key: .arrowUp)
                specialKeyButton("↓", key: .arrowDown)
                specialKeyButton("Home", key: .home)
                specialKeyButton("End", key: .end)
                specialKeyButton("PgUp", key: .pageUp)
                specialKeyButton("PgDn", key: .pageDown)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func specialKeyButton(_ label: String, key: SpecialKey) -> some View {
        Button {
            viewModel.sendSpecialKey(key)
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(minWidth: 36)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                )
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Delete-Aware Text Field (UIKit Bridge)

/// A UITextField wrapper that intercepts `deleteBackward()` even when the text field is empty.
/// This allows sending the delete key event to the Mac when the user presses backspace.
struct DeleteAwareTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onTextChange: (String) -> Void
    var onDelete: () -> Void
    var onReturn: () -> Void

    func makeUIView(context: Context) -> DeleteCapturingTextField {
        let textField = DeleteCapturingTextField()
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        textField.onDeleteBackward = onDelete
        textField.autocorrectionType = .default
        textField.autocapitalizationType = .none
        textField.returnKeyType = .send
        textField.font = .systemFont(ofSize: 16)
        textField.becomeFirstResponder()
        return textField
    }

    func updateUIView(_ uiView: DeleteCapturingTextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.onDeleteBackward = onDelete
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onTextChange: onTextChange, onReturn: onReturn)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let onTextChange: (String) -> Void
        let onReturn: () -> Void

        init(text: Binding<String>, onTextChange: @escaping (String) -> Void, onReturn: @escaping () -> Void) {
            _text = text
            self.onTextChange = onTextChange
            self.onReturn = onReturn
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            guard let stringRange = Range(range, in: current) else { return true }
            let updated = current.replacingCharacters(in: stringRange, with: string)
            text = updated
            onTextChange(updated)
            return false // We handle updating manually
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onReturn()
            return false
        }
    }
}

/// Custom UITextField subclass that captures deleteBackward() even when empty.
class DeleteCapturingTextField: UITextField {
    var onDeleteBackward: (() -> Void)?

    override func deleteBackward() {
        if text?.isEmpty ?? true {
            // Field is empty — forward the delete key to the Mac
            onDeleteBackward?()
        } else {
            super.deleteBackward()
            // Also send delete for non-empty (the text change handler will update)
            onDeleteBackward?()
        }
    }
}
