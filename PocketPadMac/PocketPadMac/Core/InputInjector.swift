// InputInjector.swift
// PocketPadMac
// CGEvent-based input injection for cursor, mouse, scroll, keyboard

import Cocoa
import CoreGraphics

/// Handles all macOS input injection via CGEvent APIs.
/// Requires Accessibility permission to function.
final class InputInjector {

    // MARK: - Permission Check

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
    }

    static func requestAccessibilityPermission() -> Bool {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
    }

    // MARK: - Cursor Movement

    /// Moves the cursor by a delta amount relative to current position.
    func moveCursor(deltaX: Double, deltaY: Double) {
        let currentPos = currentCursorPosition
        let newX = currentPos.x + deltaX
        let newY = currentPos.y + deltaY
        let point = CGPoint(x: newX, y: newY)

        guard let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                   mouseCursorPosition: point, mouseButton: .left) else { return }
        event.post(tap: .cghidEventTap)
    }

    /// Sets the cursor to an absolute position.
    func setCursorPosition(x: Double, y: Double) {
        let point = CGPoint(x: x, y: y)
        guard let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                   mouseCursorPosition: point, mouseButton: .left) else { return }
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Mouse Clicks

    func mouseDown(button: MouseButton, at point: CGPoint? = nil) {
        let pos = point ?? currentCursorPosition
        let (downType, cgButton) = cgEventParams(for: button, isDown: true)
        guard let event = CGEvent(mouseEventSource: nil, mouseType: downType,
                                   mouseCursorPosition: pos, mouseButton: cgButton) else { return }
        event.post(tap: .cghidEventTap)
    }

    func mouseUp(button: MouseButton, at point: CGPoint? = nil) {
        let pos = point ?? currentCursorPosition
        let (upType, cgButton) = cgEventParams(for: button, isDown: false)
        guard let event = CGEvent(mouseEventSource: nil, mouseType: upType,
                                   mouseCursorPosition: pos, mouseButton: cgButton) else { return }
        event.post(tap: .cghidEventTap)
    }

    func click(button: MouseButton) {
        mouseDown(button: button)
        usleep(10_000) // 10ms between down and up for reliable click
        mouseUp(button: button)
    }

    func doubleClick(button: MouseButton) {
        let pos = currentCursorPosition
        let (downType, cgButton) = cgEventParams(for: button, isDown: true)
        let (upType, _) = cgEventParams(for: button, isDown: false)

        // First click
        if let down = CGEvent(mouseEventSource: nil, mouseType: downType,
                               mouseCursorPosition: pos, mouseButton: cgButton) {
            down.setIntegerValueField(.mouseEventClickState, value: 1)
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(mouseEventSource: nil, mouseType: upType,
                             mouseCursorPosition: pos, mouseButton: cgButton) {
            up.setIntegerValueField(.mouseEventClickState, value: 1)
            up.post(tap: .cghidEventTap)
        }

        usleep(50_000) // 50ms delay between clicks

        // Second click
        if let down = CGEvent(mouseEventSource: nil, mouseType: downType,
                               mouseCursorPosition: pos, mouseButton: cgButton) {
            down.setIntegerValueField(.mouseEventClickState, value: 2)
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(mouseEventSource: nil, mouseType: upType,
                             mouseCursorPosition: pos, mouseButton: cgButton) {
            up.setIntegerValueField(.mouseEventClickState, value: 2)
            up.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Drag

    func dragMove(deltaX: Double, deltaY: Double, button: MouseButton = .left) {
        let currentPos = currentCursorPosition
        let newX = currentPos.x + deltaX
        let newY = currentPos.y + deltaY
        let point = CGPoint(x: newX, y: newY)

        let dragType: CGEventType = button == .left ? .leftMouseDragged : .rightMouseDragged
        let cgButton: CGMouseButton = button == .left ? .left : .right

        guard let event = CGEvent(mouseEventSource: nil, mouseType: dragType,
                                   mouseCursorPosition: point, mouseButton: cgButton) else { return }
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Scroll

    func scroll(deltaX: Double, deltaY: Double) {
        // Use pixel-level scrolling for smoothness
        guard let event = CGEvent(scrollWheelEvent2Source: nil,
                                   units: .pixel,
                                   wheelCount: 2,
                                   wheel1: Int32(deltaY),
                                   wheel2: Int32(deltaX),
                                   wheel3: 0) else { return }
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Keyboard

    /// Types a string by inserting it at the current cursor position using CGEvent keyboard simulation.
    func typeText(_ text: String) {
        for char in text {
            let str = String(char)
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { continue }
            let uniChars = Array(str.utf16)
            event.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)
            event.post(tap: .cghidEventTap)

            // Key up
            guard let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { continue }
            upEvent.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)
            upEvent.post(tap: .cghidEventTap)
        }
    }

    /// Sends a special key event (Enter, Delete, arrows, etc.)
    func sendSpecialKey(_ keyCode: UInt16, isDown: Bool, modifiers: ModifierFlags = []) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: isDown) else { return }

        var flags = CGEventFlags()
        if modifiers.contains(.shift)   { flags.insert(.maskShift) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option)  { flags.insert(.maskAlternate) }
        if modifiers.contains(.command) { flags.insert(.maskCommand) }

        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    /// Sends a keyboard shortcut (e.g., Cmd+C)
    func sendKeyboardShortcut(key: String, modifiers: ModifierFlags) {
        guard let keyCode = keyCodeForCharacter(key) else {
            // Fallback: type the character with modifiers held
            sendSpecialKeyWithCharacter(key, modifiers: modifiers)
            return
        }

        // Key down with modifiers
        sendSpecialKey(keyCode, isDown: true, modifiers: modifiers)
        usleep(10_000)
        // Key up
        sendSpecialKey(keyCode, isDown: false, modifiers: modifiers)
    }

    // MARK: - System Gestures

    /// Performs a macOS system gesture by simulating the corresponding keyboard shortcut or launching system apps directly.
    func performSystemGesture(_ gesture: SystemGestureType, deltaX: Double = 0, deltaY: Double = 0) {
        switch gesture {
        case .missionControl:
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-a", "Mission Control"]
            try? task.run()

        case .appExpose:
            // Ctrl + Down Arrow (default macOS shortcut for App Exposé)
            sendSpecialKey(SpecialKey.arrowDown.rawValue, isDown: true, modifiers: .control)
            usleep(10_000)
            sendSpecialKey(SpecialKey.arrowDown.rawValue, isDown: false, modifiers: .control)

        case .switchSpaceLeft:
            // Ctrl + Left Arrow (switch to left space)
            sendSpecialKey(SpecialKey.arrowLeft.rawValue, isDown: true, modifiers: .control)
            usleep(10_000)
            sendSpecialKey(SpecialKey.arrowLeft.rawValue, isDown: false, modifiers: .control)

        case .switchSpaceRight:
            // Ctrl + Right Arrow (switch to right space)
            sendSpecialKey(SpecialKey.arrowRight.rawValue, isDown: true, modifiers: .control)
            usleep(10_000)
            sendSpecialKey(SpecialKey.arrowRight.rawValue, isDown: false, modifiers: .control)

        case .launchpad:
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-a", "Launchpad"]
            try? task.run()

        case .showDesktop:
            // F11 key (default Show Desktop shortcut)
            sendSpecialKey(SpecialKey.f11.rawValue, isDown: true)
            usleep(10_000)
            sendSpecialKey(SpecialKey.f11.rawValue, isDown: false)

        case .zoomIn:
            // Cmd + = (zoom in)
            sendKeyboardShortcut(key: "=", modifiers: .command)

        case .zoomOut:
            // Cmd + - (zoom out)
            sendKeyboardShortcut(key: "-", modifiers: .command)

        case .threeFingerDragBegan:
            // Start a drag operation (mouse down at current position)
            mouseDown(button: .left)

        case .threeFingerDragMoved:
            // Move during drag
            dragMove(deltaX: deltaX, deltaY: deltaY, button: .left)

        case .threeFingerDragEnded:
            // End drag (mouse up)
            mouseUp(button: .left)
        }
    }

    // MARK: - Pinch to Zoom

    func pinchZoom(scale: Double, atPosition pos: CGPoint? = nil) {
        let position = pos ?? currentCursorPosition
        guard let event = CGEvent(source: nil) else { return }

        // Use smart zoom (double-tap with two fingers) as a simulated pinch
        // True hardware pinch requires private APIs; we use Ctrl+scroll as fallback
        event.type = .scrollWheel
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(scale > 1 ? 5 : -5))
        event.flags = .maskControl
        event.location = position
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Helpers

    private var currentCursorPosition: CGPoint {
        return CGEvent(source: nil)?.location ?? .zero
    }

    private func cgEventParams(for button: MouseButton, isDown: Bool) -> (CGEventType, CGMouseButton) {
        switch button {
        case .left:
            return (isDown ? .leftMouseDown : .leftMouseUp, .left)
        case .right:
            return (isDown ? .rightMouseDown : .rightMouseUp, .right)
        case .middle:
            return (isDown ? .otherMouseDown : .otherMouseUp, .center)
        }
    }

    /// Maps a character string to a macOS virtual key code for shortcut support.
    private func keyCodeForCharacter(_ char: String) -> UInt16? {
        let map: [String: UInt16] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5,
            "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
            "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18,
            "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24,
            "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30,
            "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
            "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43,
            "/": 44, "n": 45, "m": 46, ".": 47, " ": 49,
            "`": 50,
        ]
        return map[char.lowercased()]
    }

    private func sendSpecialKeyWithCharacter(_ char: String, modifiers: ModifierFlags) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { return }
        let uniChars = Array(char.utf16)
        event.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)

        var flags = CGEventFlags()
        if modifiers.contains(.shift)   { flags.insert(.maskShift) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option)  { flags.insert(.maskAlternate) }
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        event.flags = flags

        event.post(tap: .cghidEventTap)

        if let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
            upEvent.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)
            upEvent.flags = flags
            upEvent.post(tap: .cghidEventTap)
        }
    }
}
