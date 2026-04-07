// iOSOnboardingView.swift
// PocketPadIOS
// First-launch onboarding for the iPhone app

import SwiftUI

struct iOSOnboardingView: View {
    @EnvironmentObject var viewModel: TrackpadViewModel
    @State private var currentPage = 0

    private let features: [(icon: String, title: String, description: String, gradient: [Color])] = [
        ("hand.point.up.fill", "Your Pocket Trackpad",
         "Turn your iPhone into a high-quality wireless trackpad for your Mac.",
         [.blue, .purple]),
        ("hand.draw", "Natural Gestures",
         "Tap to click, two-finger scroll, drag, and more — just like a real trackpad.",
         [.purple, .pink]),
        ("keyboard", "Full Keyboard",
         "Rotate to landscape for a keyboard with shortcuts, modifiers, and multilingual support.",
         [.orange, .red]),
        ("wifi", "Instant Connection",
         "Finds your Mac automatically. No setup, no cables, no cloud.",
         [.green, .teal]),
        ("hand.raised.fingers.4", "iPad Multitasking",
         "On iPad, disable 'Four & Five Finger Gestures' in the Settings app to use 4-finger swipes here.",
         [.blue, .orange])
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    viewModel.completeOnboarding()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.trailing, 20)
                .padding(.top, 10)
            }

            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<features.count, id: \.self) { index in
                    onboardingPage(features[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Action button
            Button {
                if currentPage < features.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    viewModel.completeOnboarding()
                }
            } label: {
                Text(currentPage < features.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: features[currentPage].gradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .animation(.easeInOut, value: currentPage)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func onboardingPage(_ feature: (icon: String, title: String, description: String, gradient: [Color])) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: feature.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: feature.gradient[0].opacity(0.4), radius: 30, x: 0, y: 15)

                Image(systemName: feature.icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.white)
            }

            // Text
            VStack(spacing: 12) {
                Text(feature.title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(feature.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}
