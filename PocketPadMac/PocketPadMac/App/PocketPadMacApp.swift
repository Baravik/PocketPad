// PocketPadMacApp.swift
// PocketPadMac
// Main entry point for the Mac companion app

import SwiftUI

@main
struct PocketPadMacApp: App {
    @StateObject private var sessionManager = MacSessionManager()
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var settingsManager = MacSettingsManager()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some Scene {
        // Menu bar presence
        MenuBarExtra {
            MenuBarView()
                .environmentObject(sessionManager)
                .environmentObject(permissionManager)
                .environmentObject(settingsManager)
        } label: {
            Image(systemName: menuBarIcon)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Settings {
            MacSettingsView()
                .environmentObject(sessionManager)
                .environmentObject(permissionManager)
                .environmentObject(settingsManager)
        }

        // Main window (shown on first launch / onboarding)
        WindowGroup("PocketPad") {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .environmentObject(permissionManager)
                    .environmentObject(sessionManager)
                    .frame(width: 520, height: 580)
            } else {
                MainWindowView()
                    .environmentObject(sessionManager)
                    .environmentObject(permissionManager)
                    .environmentObject(settingsManager)
                    .frame(minWidth: 400, minHeight: 500)
            }
        }
        .defaultSize(width: 520, height: 580)
    }

    private var menuBarIcon: String {
        switch sessionManager.connectionState {
        case .connected:     return "hand.point.up.fill"
        case .connecting, .reconnecting: return "hand.point.up"
        case .discovering:   return "hand.point.up"
        case .disconnected:  return "hand.point.up"
        }
    }
}
