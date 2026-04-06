// iOSSettingsView.swift
// PocketPadIOS
// Settings sheet for the iPhone app

import SwiftUI

struct iOSSettingsView: View {
    @EnvironmentObject var viewModel: TrackpadViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Connection Section
                Section("Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 6) {
                            ConnectionDot(state: viewModel.sessionManager.connectionState)
                            Text(viewModel.sessionManager.connectionState.displayName)
                                .foregroundColor(.secondary)
                        }
                    }

                    if viewModel.sessionManager.connectionState == .connected {
                        HStack {
                            Text("Connected to")
                            Spacer()
                            Text(viewModel.sessionManager.connectedMacName)
                                .foregroundColor(.secondary)
                        }

                        Button(role: .destructive) {
                            viewModel.disconnect()
                        } label: {
                            Text("Disconnect")
                        }
                    } else {
                        Button {
                            viewModel.sessionManager.startBrowsing()
                        } label: {
                            Text("Start Searching")
                        }
                    }

                    Toggle("Auto-Reconnect", isOn: $viewModel.autoReconnect)
                }

                // Trackpad Section
                Section("Trackpad") {
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Slider(value: $viewModel.sensitivity, in: 0.1...3.0, step: 0.1)
                            .frame(width: 160)
                        Text(String(format: "%.1f", viewModel.sensitivity))
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                    }

                    Toggle("Tap to Click", isOn: $viewModel.tapToClick)
                    Toggle("Secondary Click (Two-Finger Tap)", isOn: $viewModel.secondaryClick)
                }

                // Feedback Section
                Section("Feedback") {
                    Toggle("Haptic Feedback", isOn: $viewModel.hapticFeedbackEnabled)
                }

                // Keyboard Section
                Section("Keyboard") {
                    Toggle("Show Keyboard in Landscape", isOn: $viewModel.showKeyboardInLandscape)
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Protocol Version")
                        Spacer()
                        Text("\(PocketPadService.protocolVersion)")
                            .foregroundColor(.secondary)
                    }

                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                }

                // Reset
                Section {
                    Button("Reset to Defaults") {
                        viewModel.sensitivity = 1.0
                        viewModel.tapToClick = true
                        viewModel.secondaryClick = true
                        viewModel.hapticFeedbackEnabled = true
                        viewModel.autoReconnect = true
                        viewModel.showKeyboardInLandscape = true
                        viewModel.updateSettings()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.updateSettings()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title.weight(.bold))

                Group {
                    Text("Data Collection")
                        .font(.headline)
                    Text("PocketPad does not collect, store, or transmit any personal data. All communication between your iPhone and Mac occurs exclusively over your local network.")

                    Text("Local Network Only")
                        .font(.headline)
                    Text("PocketPad uses Multipeer Connectivity to communicate directly with your Mac. No data is sent to external servers, cloud services, or third parties.")

                    Text("Keyboard Input")
                        .font(.headline)
                    Text("Text you type is sent directly to your Mac over the local network. It is never stored on the iPhone, logged, or transmitted to any other destination.")

                    Text("Permissions")
                        .font(.headline)
                    Text("""
                    • Local Network: Required to discover and communicate with your Mac.
                    • Accessibility (Mac): Required for the Mac app to control cursor and keyboard input.
                    
                    No other permissions are required or requested.
                    """)

                    Text("Analytics")
                        .font(.headline)
                    Text("PocketPad includes no analytics, tracking, or telemetry of any kind.")

                    Text("Contact")
                        .font(.headline)
                    Text("For questions about this privacy policy, contact the developer.")
                }
                .font(.body)
            }
            .padding(20)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
