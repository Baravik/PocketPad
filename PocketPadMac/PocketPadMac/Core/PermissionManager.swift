// PermissionManager.swift
// PocketPadMac
// Manages macOS system permissions required for input injection

import Cocoa
import CoreGraphics

/// Manages Accessibility and Input Monitoring permissions.
/// macOS requires explicit user approval for apps that control the Mac through Accessibility features.
final class PermissionManager: ObservableObject {

    enum PermissionStatus: String {
        case granted
        case denied
        case unknown
    }

    @Published var accessibilityStatus: PermissionStatus = .unknown
    @Published var inputMonitoringStatus: PermissionStatus = .unknown

    private var checkTimer: Timer?

    init() {
        checkPermissions()
    }

    // MARK: - Check Permissions

    func checkPermissions() {
        checkAccessibility()
        checkInputMonitoring()
    }

    /// Checks if Accessibility permission is granted.
    /// CGEvent-based input injection requires this permission.
    func checkAccessibility() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
        accessibilityStatus = trusted ? .granted : .denied
    }

    /// Requests Accessibility permission with the system prompt.
    func requestAccessibility() {
        let _ = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        // Start polling for when user grants permission
        startPolling()
    }

    /// Checks if Input Monitoring permission is available.
    /// Input Monitoring is needed for some advanced keyboard event handling,
    /// but basic CGEvent-based injection works with just Accessibility.
    func checkInputMonitoring() {
        // Input monitoring is implicitly granted when Accessibility is granted
        // for CGEvent-based injection. We track it separately for future use.
        if accessibilityStatus == .granted {
            inputMonitoringStatus = .granted
        } else {
            inputMonitoringStatus = .unknown
        }
    }

    /// Opens System Settings to the Accessibility pane.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens System Settings to the Input Monitoring pane.
    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Polling

    /// Polls for permission changes after the user has been prompted.
    func startPolling() {
        stopPolling()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkPermissions()
            if self.accessibilityStatus == .granted {
                self.stopPolling()
            }
        }
    }

    func stopPolling() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    deinit {
        stopPolling()
    }
}
