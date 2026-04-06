// ContentView.swift
// PocketPadIOS
// Root view that switches between onboarding and main trackpad interface

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: TrackpadViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var orientation = UIDeviceOrientation.portrait

    var body: some View {
        Group {
            if viewModel.showOnboarding {
                iOSOnboardingView()
                    .environmentObject(viewModel)
            } else {
                mainContent
            }
        }
        .onAppear {
            viewModel.onAppear()
            setupOrientationObserver()
        }
        .onChange(of: viewModel.hapticFeedbackEnabled) { _ in
            viewModel.updateSettings()
        }
        .sheet(isPresented: $viewModel.showSettings) {
            iOSSettingsView()
                .environmentObject(viewModel)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLandscape {
            LandscapeTrackpadView()
                .environmentObject(viewModel)
        } else {
            PortraitTrackpadView()
                .environmentObject(viewModel)
        }
    }

    private func setupOrientationObserver() {
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let orientation = UIDevice.current.orientation
            if orientation.isLandscape || orientation.isPortrait {
                viewModel.isLandscape = orientation.isLandscape
            }
        }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }
}

// MARK: - Portrait Layout

struct PortraitTrackpadView: View {
    @EnvironmentObject var viewModel: TrackpadViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Status Bar
            StatusBarView()
                .environmentObject(viewModel)

            // Trackpad Surface
            ZStack {
                // Background gradient
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.systemBackground),
                                Color(.systemGray6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 2)

                // Border
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(.systemGray4), lineWidth: 0.5)

                // Touch surface
                TrackpadSurface(
                    onGesture: { gesture in
                        viewModel.handleGesture(gesture)
                    },
                    tapToClick: viewModel.tapToClick,
                    secondaryClick: viewModel.secondaryClick,
                    sensitivity: CGFloat(viewModel.sensitivity)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Drag hint
                if viewModel.sessionManager.connectionState == .connected {
                    VStack {
                        Spacer()
                        Text("Touch to move cursor")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                            .padding(.bottom, 8)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Bottom Toolbar
            BottomToolbarView()
                .environmentObject(viewModel)
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Landscape Layout

struct LandscapeTrackpadView: View {
    @EnvironmentObject var viewModel: TrackpadViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Trackpad (left half)
            VStack(spacing: 0) {
                // Mini status
                HStack {
                    ConnectionDot(state: viewModel.sessionManager.connectionState)
                    Text(viewModel.sessionManager.connectedMacName.isEmpty ? "PocketPad" : viewModel.sessionManager.connectedMacName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 5)

                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(.systemGray4), lineWidth: 0.5)

                    TrackpadSurface(
                        onGesture: { gesture in
                            viewModel.handleGesture(gesture)
                        },
                        tapToClick: viewModel.tapToClick,
                        secondaryClick: viewModel.secondaryClick,
                        sensitivity: CGFloat(viewModel.sensitivity)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 0.5)

            // Keyboard / Controls (right half)
            VStack(spacing: 0) {
                if viewModel.showKeyboard {
                    KeyboardInputView()
                        .environmentObject(viewModel)
                } else {
                    // Show quick actions when keyboard is hidden
                    LandscapeQuickActions()
                        .environmentObject(viewModel)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Landscape Quick Actions

struct LandscapeQuickActions: View {
    @EnvironmentObject var viewModel: TrackpadViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Button {
                viewModel.showKeyboard = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 36))
                    Text("Open Keyboard")
                        .font(.caption)
                }
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.1))
                )
            }
            .padding(.horizontal, 20)

            // Quick shortcut buttons
            HStack(spacing: 12) {
                shortcutButton("Cmd-C", key: "c", mod: .command)
                shortcutButton("Cmd-V", key: "v", mod: .command)
                shortcutButton("Cmd-Z", key: "z", mod: .command)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                shortcutButton("Cmd-Tab", key: "\t", mod: .command)
                shortcutButton("Space", key: " ", mod: [])
                shortcutButton("Esc", key: "", mod: [], specialKey: .escape)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func shortcutButton(_ label: String, key: String, mod: ModifierFlags, specialKey: SpecialKey? = nil) -> some View {
        Button {
            if let sk = specialKey {
                viewModel.sendSpecialKey(sk)
            } else {
                viewModel.sendShortcut(key: key, modifiers: mod)
            }
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
    }
}
