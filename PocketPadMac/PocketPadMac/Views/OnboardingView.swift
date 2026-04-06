// OnboardingView.swift
// PocketPadMac
// First-launch onboarding flow with permission setup

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var sessionManager: MacSessionManager
    @State private var currentPage = 0

    private let totalPages = 4

    var body: some View {
        VStack(spacing: 0) {
            // Content
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                accessibilityPage.tag(1)
                howItWorksPage.tag(2)
                readyPage.tag(3)
            }
            .tabViewStyle(.automatic)
            .animation(.easeInOut, value: currentPage)

            // Navigation
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation { currentPage -= 1 }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                if currentPage < totalPages - 1 {
                    Button("Next") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else {
                    Button("Get Started") {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        sessionManager.startAdvertising()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(24)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)

            Text("Welcome to PocketPad")
                .font(.largeTitle.weight(.bold))

            Text("Turn your iPhone into a high-quality\nwireless trackpad for your Mac")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(32)
    }

    private var accessibilityPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Permission Required")
                .font(.title2.weight(.bold))

            Text("PocketPad needs Accessibility permission to control your cursor and keyboard. This is a standard macOS security requirement for any app that simulates input.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: permissionManager.accessibilityStatus == .granted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(permissionManager.accessibilityStatus == .granted ? .green : .orange)
                    Text("Accessibility Access")
                        .font(.subheadline)
                    Spacer()
                    if permissionManager.accessibilityStatus == .granted {
                        Text("Granted")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 20)
            }

            if permissionManager.accessibilityStatus != .granted {
                Button {
                    permissionManager.requestAccessibility()
                } label: {
                    Label("Grant Accessibility Permission", systemImage: "lock.open")
                        .frame(width: 260)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Label("Permission Granted!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.headline)
            }

            Spacer()
        }
        .padding(32)
        .onAppear {
            permissionManager.startPolling()
        }
    }

    private var howItWorksPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("How It Works")
                .font(.title2.weight(.bold))

            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "iphone", title: "Open PocketPad on iPhone", subtitle: "Your iPhone becomes a wireless trackpad")
                featureRow(icon: "wifi", title: "Auto-Discovery", subtitle: "Devices find each other automatically over Wi-Fi")
                featureRow(icon: "hand.draw", title: "Touch to Control", subtitle: "Swipe, tap, scroll — just like a real trackpad")
                featureRow(icon: "keyboard", title: "Type Anywhere", subtitle: "Rotate to landscape for a full keyboard")
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(32)
    }

    private var readyPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title2.weight(.bold))

            Text("PocketPad will appear in your menu bar and start listening for your iPhone automatically.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "menubar.arrow.down.rectangle")
                    Text("Find PocketPad in the menu bar")
                }
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Auto-reconnects if connection drops")
                }
                HStack {
                    Image(systemName: "gearshape")
                    Text("Customize in Settings")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.top, 8)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Helpers

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
