// MenuBarView.swift
// PocketPadMac
// Menu bar popover showing connection status and quick controls

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var sessionManager: MacSessionManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var settingsManager: MacSettingsManager

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "hand.point.up.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("PocketPad")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)

            // Connection Status
            connectionStatusCard

            Divider()

            // Quick Actions
            if sessionManager.connectionState == .disconnected {
                Button {
                    sessionManager.startAdvertising()
                } label: {
                    Label("Start Listening", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if sessionManager.connectionState == .connected {
                Button(role: .destructive) {
                    sessionManager.stopAdvertising()
                } label: {
                    Label("Disconnect", systemImage: "wifi.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            // Permission Warning
            if permissionManager.accessibilityStatus != .granted {
                permissionWarning
            }

            Divider()

            // Footer actions
            HStack {
                Button("Settings…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 300)
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        HStack(spacing: 12) {
            // Status Indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: sessionManager.connectionState.systemImageName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(sessionManager.connectionState.displayName)
                    .font(.subheadline.weight(.medium))
                if sessionManager.connectionState == .connected {
                    Text(sessionManager.connectedDeviceName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let battery = sessionManager.remoteBatteryLevel {
                        HStack(spacing: 4) {
                            Image(systemName: batteryIcon(level: battery))
                                .font(.caption2)
                            Text("\(Int(battery * 100))%")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if sessionManager.connectionState == .connecting || sessionManager.connectionState == .reconnecting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
    }

    // MARK: - Permission Warning

    private var permissionWarning: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Accessibility permission required")
                    .font(.caption.weight(.medium))
                Spacer()
            }
            Button("Grant Permission") {
                permissionManager.requestAccessibility()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.orange.opacity(0.1)))
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch sessionManager.connectionState {
        case .connected:     return .green
        case .connecting:    return .orange
        case .reconnecting:  return .orange
        case .discovering:   return .blue
        case .disconnected:  return .gray
        }
    }

    private func batteryIcon(level: Float) -> String {
        switch level {
        case 0.75...:    return "battery.100"
        case 0.50..<0.75: return "battery.75"
        case 0.25..<0.50: return "battery.50"
        default:          return "battery.25"
        }
    }
}
