// MacSettingsManager.swift
// PocketPadMac
// Persistent settings for the Mac companion app

import Foundation
import SwiftUI
import ServiceManagement

/// Manages all Mac app settings with UserDefaults persistence.
final class MacSettingsManager: ObservableObject {

    // MARK: - Trackpad Settings

    @AppStorage("sensitivity") var sensitivity: Double = 1.0
    @AppStorage("acceleration") var acceleration: Double = 1.0
    @AppStorage("naturalScrolling") var naturalScrolling: Bool = true
    @AppStorage("tapToClick") var tapToClick: Bool = true
    @AppStorage("secondaryClick") var secondaryClick: Bool = true

    // MARK: - App Settings

    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet {
            updateLaunchAtLogin()
        }
    }

    @AppStorage("autoReconnect") var autoReconnect: Bool = true
    @AppStorage("showDebugPanel") var showDebugPanel: Bool = false

    // MARK: - Appearance

    @AppStorage("appTheme") var appTheme: String = "system" // "system", "light", "dark"

    // MARK: - Launch at Login

    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }

    // MARK: - Export as TrackpadSettings

    func trackpadSettings() -> TrackpadSettings {
        TrackpadSettings(
            sensitivity: sensitivity,
            acceleration: acceleration,
            naturalScrolling: naturalScrolling,
            tapToClick: tapToClick,
            secondaryClick: secondaryClick,
            hapticFeedback: true
        )
    }

    // MARK: - Apply TrackpadSettings

    func apply(_ settings: TrackpadSettings) {
        sensitivity = settings.sensitivity
        acceleration = settings.acceleration
        naturalScrolling = settings.naturalScrolling
        tapToClick = settings.tapToClick
        secondaryClick = settings.secondaryClick
    }

    // MARK: - Reset

    func resetToDefaults() {
        sensitivity = 1.0
        acceleration = 1.0
        naturalScrolling = true
        tapToClick = true
        secondaryClick = true
        autoReconnect = true
        showDebugPanel = false
        appTheme = "system"
    }
}
