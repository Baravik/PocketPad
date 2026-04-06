// MainWindowView.swift
// PocketPadMac
// Primary window showing connection status and device management

import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var sessionManager: MacSessionManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var settingsManager: MacSettingsManager

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detailContent
        }
        .onAppear {
            permissionManager.checkPermissions()
            if permissionManager.accessibilityStatus == .granted {
                sessionManager.startAdvertising()
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List {
            Section("Connection") {
                NavigationLink(value: "status") {
                    Label("Status", systemImage: "wifi")
                }
            }

            Section("Configuration") {
                NavigationLink(value: "trackpad") {
                    Label("Trackpad", systemImage: "hand.point.up")
                }
                NavigationLink(value: "permissions") {
                    Label("Permissions", systemImage: "lock.shield")
                }
            }

            if settingsManager.showDebugPanel {
                Section("Developer") {
                    NavigationLink(value: "debug") {
                        Label("Debug", systemImage: "ladybug")
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail Content

    private var detailContent: some View {
        VStack(spacing: 0) {
            // Permission banner if needed
            if permissionManager.accessibilityStatus != .granted {
                permissionBanner
            }

            // Main content
            connectionView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Connection View

    private var connectionView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Large status icon
            ZStack {
                Circle()
                    .fill(statusGradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: statusColor.opacity(0.3), radius: 20, x: 0, y: 8)

                Image(systemName: sessionManager.connectionState == .connected ? "checkmark" : "hand.point.up.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
            }
            .animation(.spring(response: 0.5), value: sessionManager.connectionState)

            // Status text
            VStack(spacing: 8) {
                Text(sessionManager.connectionState.displayName)
                    .font(.title2.weight(.semibold))

                if sessionManager.connectionState == .connected {
                    Text("Connected to \(sessionManager.connectedDeviceName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if sessionManager.connectionState == .discovering {
                    Text("Open PocketPad on your iPhone to connect")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if sessionManager.connectionState == .disconnected {
                    Text("Start listening to accept connections")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Action button
            actionButton

            Spacer()

            // Battery info if connected
            if sessionManager.connectionState == .connected, let battery = sessionManager.remoteBatteryLevel {
                HStack {
                    Image(systemName: "battery.75")
                    Text("iPhone Battery: \(Int(battery * 100))%")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
            }
        }
        .padding()
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        switch sessionManager.connectionState {
        case .disconnected:
            Button {
                sessionManager.startAdvertising()
            } label: {
                Label("Start Listening", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline)
                    .frame(width: 200, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .discovering, .connecting:
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for iPhone…")
                    .foregroundColor(.secondary)
            }

        case .connected:
            Button(role: .destructive) {
                sessionManager.stopAdvertising()
            } label: {
                Label("Disconnect", systemImage: "wifi.slash")
                    .frame(width: 200, height: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

        case .reconnecting:
            VStack(spacing: 8) {
                ProgressView()
                Text("Reconnecting…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility Permission Required")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text("PocketPad needs permission to control your cursor and keyboard")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            Button("Grant") {
                permissionManager.requestAccessibility()
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.gradient)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch sessionManager.connectionState {
        case .connected:    return .green
        case .connecting, .reconnecting: return .orange
        case .discovering:  return .blue
        case .disconnected: return .gray
        }
    }

    private var statusGradient: LinearGradient {
        LinearGradient(
            colors: [statusColor, statusColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
