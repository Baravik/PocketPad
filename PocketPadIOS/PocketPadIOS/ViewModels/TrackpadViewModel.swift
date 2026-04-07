// TrackpadViewModel.swift
// PocketPadIOS
// Main view model coordinating gesture input, networking, and haptics

import Foundation
import SwiftUI
import Combine

@MainActor
final class TrackpadViewModel: ObservableObject {

    // MARK: - Published State

    @Published var showKeyboard = false
    @Published var showSettings = false
    @Published var showOnboarding: Bool
    @Published var isLandscape = false
    @Published var keyboardText = ""
    @Published var activeFingerCount = 0

    // Modifier key states for keyboard toolbar
    @Published var commandActive = false
    @Published var optionActive = false
    @Published var controlActive = false
    @Published var shiftActive = false

    // MARK: - Dependencies

    let sessionManager = iOSSessionManager()
    let hapticEngine = HapticEngine()

    // MARK: - Settings (persisted)

    @AppStorage("sensitivity") var sensitivity: Double = 1.0
    @AppStorage("hapticFeedback") var hapticFeedbackEnabled: Bool = true
    @AppStorage("tapToClick") var tapToClick: Bool = true
    @AppStorage("secondaryClick") var secondaryClick: Bool = true
    @AppStorage("showKeyboardInLandscape") var showKeyboardInLandscape: Bool = true
    @AppStorage("autoReconnect") var autoReconnect: Bool = true

    // MARK: - Init

    init() {
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        self.showOnboarding = !hasSeenOnboarding
        hapticEngine.isEnabled = hapticFeedbackEnabled
    }

    // MARK: - Lifecycle

    func onAppear() {
        sessionManager.autoReconnect = autoReconnect
        if !showOnboarding {
            sessionManager.startBrowsing()
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        showOnboarding = false
        sessionManager.startBrowsing()
    }

    // MARK: - Gesture Processing

    func handleGesture(_ gesture: TrackpadGesture) {
        switch gesture {
        case .move(let dx, let dy):
            sessionManager.sendCursorMove(dx: Double(dx), dy: Double(dy))

        case .tap(let fingers):
            if fingers == 1 {
                sessionManager.sendClick(button: .left, action: .single)
                hapticEngine.tapFeedback()
            } else if fingers == 2 {
                sessionManager.sendClick(button: .right, action: .single)
                hapticEngine.rightClickFeedback()
            } else if fingers == 3 {
                sessionManager.sendClick(button: .middle, action: .single)
                hapticEngine.tapFeedback()
            }

        case .doubleTap:
            sessionManager.sendClick(button: .left, action: .double)
            hapticEngine.doubleTapFeedback()

        case .scroll(let dx, let dy):
            sessionManager.sendScroll(dx: Double(dx), dy: Double(dy))

        case .scrollEnd:
            break

        case .dragBegan:
            sessionManager.sendDrag(phase: .began, dx: 0, dy: 0)
            hapticEngine.dragStartFeedback()

        case .dragChanged(let dx, let dy):
            sessionManager.sendDrag(phase: .changed, dx: Double(dx), dy: Double(dy))

        case .dragEnded:
            sessionManager.sendDrag(phase: .ended, dx: 0, dy: 0)

        case .pinch(let scale):
            sessionManager.sendScroll(dx: 0, dy: Double(scale > 1 ? 5 : -5))

        // MARK: - Advanced System Gestures

        case .threeFingerSwipe(let direction):
            switch direction {
            case .up:
                sessionManager.sendSystemGesture(.missionControl)
            case .down:
                sessionManager.sendSystemGesture(.appExpose)
            case .left:
                sessionManager.sendSystemGesture(.switchSpaceLeft)
            case .right:
                sessionManager.sendSystemGesture(.switchSpaceRight)
            }
            hapticEngine.tapFeedback()

        case .threeFingerDragBegan:
            sessionManager.sendSystemGesture(.threeFingerDragBegan)
            hapticEngine.dragStartFeedback()

        case .threeFingerDragChanged(let dx, let dy):
            sessionManager.sendSystemGesture(.threeFingerDragMoved, dx: Double(dx), dy: Double(dy))

        case .threeFingerDragEnded:
            sessionManager.sendSystemGesture(.threeFingerDragEnded)

        case .fourFingerPinch(let closing):
            if closing {
                sessionManager.sendSystemGesture(.launchpad)
            } else {
                sessionManager.sendSystemGesture(.showDesktop)
            }
            hapticEngine.tapFeedback()
        }
    }

    // MARK: - Keyboard Input

    func sendText(_ text: String) {
        // Apply modifiers if active
        if commandActive || optionActive || controlActive || shiftActive {
            var mods = ModifierFlags()
            if commandActive { mods.insert(.command) }
            if optionActive  { mods.insert(.option) }
            if controlActive { mods.insert(.control) }
            if shiftActive   { mods.insert(.shift) }

            for char in text {
                sessionManager.sendKeyboardShortcut(key: String(char), modifiers: mods)
            }
            // Deactivate modifiers after use
            commandActive = false
            optionActive = false
            controlActive = false
            shiftActive = false
        } else {
            sessionManager.sendKeyboardText(text)
        }
        hapticEngine.keyTapFeedback()
    }

    func sendSpecialKey(_ key: SpecialKey) {
        var mods = ModifierFlags()
        if commandActive { mods.insert(.command) }
        if optionActive  { mods.insert(.option) }
        if controlActive { mods.insert(.control) }
        if shiftActive   { mods.insert(.shift) }

        sessionManager.sendSpecialKey(key, modifiers: mods)
        hapticEngine.keyTapFeedback()

        // Deactivate modifiers after special key
        commandActive = false
        optionActive = false
        controlActive = false
        shiftActive = false
    }

    func sendShortcut(key: String, modifiers: ModifierFlags) {
        sessionManager.sendKeyboardShortcut(key: key, modifiers: modifiers)
        hapticEngine.keyTapFeedback()
    }

    // MARK: - Connection

    func connectToMac(_ peer: Any) {
        // Accept MCPeerID from the peer list
        if let peerID = peer as? MCPeerID {
            sessionManager.connect(to: peerID)
        }
    }

    func disconnect() {
        sessionManager.stopBrowsing()
    }

    // MARK: - Settings

    func updateSettings() {
        hapticEngine.isEnabled = hapticFeedbackEnabled
        sessionManager.autoReconnect = autoReconnect
    }
}

import MultipeerConnectivity
