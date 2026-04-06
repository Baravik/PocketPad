// StatusBarView.swift
// PocketPadIOS
// Top status bar showing connection state and device name

import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var viewModel: TrackpadViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Connection indicator
            ConnectionDot(state: viewModel.sessionManager.connectionState)

            // Status text
            VStack(alignment: .leading, spacing: 1) {
                if viewModel.sessionManager.connectionState == .connected {
                    Text(viewModel.sessionManager.connectedMacName)
                        .font(.subheadline.weight(.semibold))
                    Text("Connected")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else {
                    Text("PocketPad")
                        .font(.subheadline.weight(.semibold))
                    Text(viewModel.sessionManager.connectionState.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Reconnecting indicator
            if viewModel.sessionManager.connectionState == .connecting ||
               viewModel.sessionManager.connectionState == .reconnecting {
                ProgressView()
                    .controlSize(.small)
            }

            // Settings button
            Button {
                viewModel.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Connection Dot

struct ConnectionDot: View {
    let state: ConnectionState

    var body: some View {
        ZStack {
            Circle()
                .fill(dotColor.opacity(0.3))
                .frame(width: 12, height: 12)

            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            if state == .connected {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: dotColor, radius: 4)
            }

            if state == .reconnecting || state == .connecting {
                Circle()
                    .stroke(dotColor, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(state == .reconnecting ? 360 : 0))
                    .animation(state == .reconnecting ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: state)
            }
        }
    }

    private var dotColor: Color {
        switch state {
        case .connected:     return .green
        case .connecting:    return .orange
        case .reconnecting:  return .orange
        case .discovering:   return .blue
        case .disconnected:  return .gray
        }
    }
}

// MARK: - Bottom Toolbar

struct BottomToolbarView: View {
    @EnvironmentObject var viewModel: TrackpadViewModel

    var body: some View {
        HStack(spacing: 24) {
            // Keyboard button
            Button {
                viewModel.showKeyboard.toggle()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: viewModel.showKeyboard ? "keyboard.chevron.compact.down" : "keyboard")
                        .font(.title3)
                    Text("Keyboard")
                        .font(.caption2)
                }
                .foregroundColor(viewModel.showKeyboard ? .accentColor : .secondary)
            }

            Spacer()

            // Connection info
            if viewModel.sessionManager.connectionState == .disconnected {
                Button {
                    viewModel.sessionManager.startBrowsing()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.title3)
                        Text("Connect")
                            .font(.caption2)
                    }
                    .foregroundColor(.accentColor)
                }
            } else if viewModel.sessionManager.connectionState == .discovering {
                PeerListButton()
                    .environmentObject(viewModel)
            }

            Spacer()

            // Settings
            Button {
                viewModel.showSettings = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                    Text("Settings")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)

        // Keyboard overlay
        if viewModel.showKeyboard && !viewModel.isLandscape {
            KeyboardInputView()
                .environmentObject(viewModel)
                .transition(.move(edge: .bottom))
        }
    }
}

// MARK: - Peer List Button

struct PeerListButton: View {
    @EnvironmentObject var viewModel: TrackpadViewModel
    @State private var showPeerList = false

    var body: some View {
        Button {
            showPeerList = true
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: "desktopcomputer")
                        .font(.title3)
                    if !viewModel.sessionManager.discoveredPeers.isEmpty {
                        Text("\(viewModel.sessionManager.discoveredPeers.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(3)
                            .background(Circle().fill(.red))
                            .offset(x: 12, y: -8)
                    }
                }
                Text("Macs Found")
                    .font(.caption2)
            }
            .foregroundColor(.accentColor)
        }
        .sheet(isPresented: $showPeerList) {
            PeerListView()
                .environmentObject(viewModel)
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Peer List View

struct PeerListView: View {
    @EnvironmentObject var viewModel: TrackpadViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.sessionManager.discoveredPeers.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Searching for Macs…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Make sure PocketPad is running on your Mac")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.sessionManager.discoveredPeers, id: \.displayName) { peer in
                        Button {
                            viewModel.connectToMac(peer)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "desktopcomputer")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading) {
                                    Text(peer.displayName)
                                        .font(.body.weight(.medium))
                                    Text("Tap to connect")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Available Macs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
