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

            // Trackpad Surface (fills available space)
            ZStack {
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

                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(.systemGray4), lineWidth: 0.5)

                TrackpadSurface(
                    onGesture: { gesture in
                        viewModel.handleGesture(gesture)
                    },
                    onFingerCountChanged: { count in
                        DispatchQueue.main.async {
                            viewModel.activeFingerCount = count
                        }
                    },
                    tapToClick: viewModel.tapToClick,
                    secondaryClick: viewModel.secondaryClick,
                    sensitivity: CGFloat(viewModel.sensitivity),
                    cornerRadius: 16
                )

                if viewModel.sessionManager.connectionState == .connected && !viewModel.showKeyboard {
                    VStack(spacing: 8) {
                        Spacer()
                        if viewModel.activeFingerCount > 0 {
                            Text("Fingers: \(viewModel.activeFingerCount)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.black.opacity(0.6)))
                        }
                        Text("Touch to move cursor")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                            .padding(.bottom, 8)
                    }
                }

                // Floating action buttons over trackpad
                if !viewModel.showKeyboard {
                    VStack {
                        Spacer()
                        HStack(spacing: 16) {
                            if viewModel.sessionManager.connectionState == .disconnected {
                                Button {
                                    viewModel.sessionManager.startBrowsing()
                                } label: {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .frame(width: 48, height: 48)
                                        .background(Circle().fill(Color.green))
                                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                                }
                            } else if viewModel.sessionManager.connectionState == .discovering {
                                PeerListButton()
                                    .environmentObject(viewModel)
                            }

                            Spacer()

                            Button {
                                viewModel.showKeyboard = true
                            } label: {
                                Image(systemName: "keyboard")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(Color.accentColor))
                                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .defersSystemGestures(on: .all)
            .persistentSystemOverlays(.hidden)

            // Keyboard (sits ABOVE iOS keyboard naturally — no ignoresSafeArea)
            if viewModel.showKeyboard {
                KeyboardInputView()
                    .environmentObject(viewModel)
            }
        }
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.2), value: viewModel.showKeyboard)
    }
}

// MARK: - Landscape Layout

struct LandscapeTrackpadView: View {
    @EnvironmentObject var viewModel: TrackpadViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Mini status bar
            HStack {
                ConnectionDot(state: viewModel.sessionManager.connectionState)
                Text(viewModel.sessionManager.connectedMacName.isEmpty ? "PocketPad" : viewModel.sessionManager.connectedMacName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()

                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)

            // Full trackpad surface
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
                    onFingerCountChanged: { count in
                        DispatchQueue.main.async {
                            viewModel.activeFingerCount = count
                        }
                    },
                    tapToClick: viewModel.tapToClick,
                    secondaryClick: viewModel.secondaryClick,
                    sensitivity: CGFloat(viewModel.sensitivity),
                    cornerRadius: 12
                )

                // Debug fingers
                if viewModel.activeFingerCount > 0 && !viewModel.showKeyboard {
                    VStack {
                        Spacer()
                        Text("Fingers: \(viewModel.activeFingerCount)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.black.opacity(0.6)))
                            .padding(.bottom, 16)
                    }
                }

                // Floating keyboard toggle
                if !viewModel.showKeyboard {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                viewModel.showKeyboard = true
                            } label: {
                                Image(systemName: "keyboard")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(Color.accentColor))
                                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                            }
                            .padding(.trailing, 12)
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
            .padding(8)
            .defersSystemGestures(on: .all)
            .persistentSystemOverlays(.hidden)

            // Keyboard (sits above iOS keyboard naturally)
            if viewModel.showKeyboard {
                KeyboardInputView()
                    .environmentObject(viewModel)
                    .frame(maxHeight: 220)
            }
        }
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.2), value: viewModel.showKeyboard)
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
