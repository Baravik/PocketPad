// MacSettingsView.swift
// PocketPadMac
// Settings panel with trackpad, app, and developer options

import SwiftUI

struct MacSettingsView: View {
    @EnvironmentObject var settingsManager: MacSettingsManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var sessionManager: MacSessionManager

    var body: some View {
        TabView {
            TrackpadSettingsTab()
                .environmentObject(settingsManager)
                .environmentObject(sessionManager)
                .tabItem {
                    Label("Trackpad", systemImage: "hand.point.up")
                }

            AppSettingsTab()
                .environmentObject(settingsManager)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            PermissionsTab()
                .environmentObject(permissionManager)
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }

            if settingsManager.showDebugPanel {
                DebugTab()
                    .environmentObject(sessionManager)
                    .tabItem {
                        Label("Debug", systemImage: "ladybug")
                    }
            }
        }
        .frame(width: 480, height: 400)
    }
}

// MARK: - Trackpad Settings

struct TrackpadSettingsTab: View {
    @EnvironmentObject var settingsManager: MacSettingsManager
    @EnvironmentObject var sessionManager: MacSessionManager

    var body: some View {
        Form {
            Section("Pointer") {
                HStack {
                    Text("Tracking Speed")
                    Spacer()
                    Slider(value: $settingsManager.sensitivity, in: 0.1...3.0, step: 0.1)
                        .frame(width: 200)
                    Text(String(format: "%.1f", settingsManager.sensitivity))
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }

                HStack {
                    Text("Acceleration")
                    Spacer()
                    Slider(value: $settingsManager.acceleration, in: 0.0...2.0, step: 0.1)
                        .frame(width: 200)
                    Text(String(format: "%.1f", settingsManager.acceleration))
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }
            }

            Section("Clicking") {
                Toggle("Tap to Click", isOn: $settingsManager.tapToClick)
                Toggle("Secondary Click (Two-Finger Tap)", isOn: $settingsManager.secondaryClick)
            }

            Section("Scrolling") {
                Toggle("Natural Scrolling", isOn: $settingsManager.naturalScrolling)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Apply to Connected Device") {
                        sessionManager.settings = settingsManager.trackpadSettings()
                        sessionManager.sendSettings()
                    }
                    .disabled(sessionManager.connectionState != .connected)

                    Button("Reset to Defaults") {
                        settingsManager.resetToDefaults()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - App Settings

struct AppSettingsTab: View {
    @EnvironmentObject var settingsManager: MacSettingsManager

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: $settingsManager.launchAtLogin)
                Toggle("Auto-Reconnect", isOn: $settingsManager.autoReconnect)
            }

            Section("Appearance") {
                Picker("Theme", selection: $settingsManager.appTheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("Developer") {
                Toggle("Show Debug Panel", isOn: $settingsManager.showDebugPanel)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Permissions

struct PermissionsTab: View {
    @EnvironmentObject var permissionManager: PermissionManager

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("macOS Security Permissions")
                        .font(.headline)
                    Text("PocketPad needs specific permissions to control your cursor and keyboard. These permissions are required by macOS for any app that simulates input events.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Accessibility") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibility Access")
                            .font(.subheadline.weight(.medium))
                        Text("Required to move cursor, click, scroll, and type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    statusBadge(permissionManager.accessibilityStatus)
                }

                if permissionManager.accessibilityStatus != .granted {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To grant permission:")
                            .font(.caption.weight(.medium))
                        Text("1. Click 'Open Settings' below")
                            .font(.caption)
                        Text("2. Find PocketPad in the list")
                            .font(.caption)
                        Text("3. Toggle it ON")
                            .font(.caption)
                        Text("4. You may need to restart PocketPad")
                            .font(.caption)

                        HStack {
                            Button("Open Settings") {
                                permissionManager.openAccessibilitySettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button("Check Again") {
                                permissionManager.checkPermissions()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section("Input Monitoring") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Input Monitoring")
                            .font(.subheadline.weight(.medium))
                        Text("May be needed for advanced keyboard features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    statusBadge(permissionManager.inputMonitoringStatus)
                }

                if permissionManager.inputMonitoringStatus != .granted {
                    Button("Open Input Monitoring Settings") {
                        permissionManager.openInputMonitoringSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            permissionManager.checkPermissions()
        }
    }

    private func statusBadge(_ status: PermissionManager.PermissionStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status == .granted ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(status == .granted ? "Granted" : "Required")
                .font(.caption)
                .foregroundColor(status == .granted ? .green : .orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((status == .granted ? Color.green : Color.orange).opacity(0.1))
        )
    }
}

// MARK: - Debug Tab

struct DebugTab: View {
    @EnvironmentObject var sessionManager: MacSessionManager
    @State private var testDelta: Double = 10

    var body: some View {
        Form {
            Section("Connection Info") {
                LabeledContent("State", value: sessionManager.connectionState.rawValue)
                LabeledContent("Peer", value: sessionManager.connectedDeviceName.isEmpty ? "None" : sessionManager.connectedDeviceName)
                if let heartbeat = sessionManager.lastHeartbeat {
                    LabeledContent("Last Heartbeat", value: heartbeat.formatted(date: .omitted, time: .standard))
                }
            }

            Section("Input Test") {
                HStack {
                    Text("Move Delta")
                    Slider(value: $testDelta, in: 1...100)
                    Text(String(format: "%.0f", testDelta))
                }

                HStack {
                    Button("Move ←") { testMove(dx: -testDelta, dy: 0) }
                    Button("Move →") { testMove(dx: testDelta, dy: 0) }
                    Button("Move ↑") { testMove(dx: 0, dy: -testDelta) }
                    Button("Move ↓") { testMove(dx: 0, dy: testDelta) }
                }

                HStack {
                    Button("Left Click") { testClick(.left) }
                    Button("Right Click") { testClick(.right) }
                    Button("Double Click") { testDoubleClick() }
                }
            }

            Section("Settings") {
                LabeledContent("Sensitivity", value: String(format: "%.1f", sessionManager.settings.sensitivity))
                LabeledContent("Acceleration", value: String(format: "%.1f", sessionManager.settings.acceleration))
                LabeledContent("Natural Scroll", value: sessionManager.settings.naturalScrolling ? "On" : "Off")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func testMove(dx: Double, dy: Double) {
        let injector = InputInjector()
        injector.moveCursor(deltaX: dx, deltaY: dy)
    }

    private func testClick(_ button: MouseButton) {
        let injector = InputInjector()
        injector.click(button: button)
    }

    private func testDoubleClick() {
        let injector = InputInjector()
        injector.doubleClick(button: .left)
    }
}
