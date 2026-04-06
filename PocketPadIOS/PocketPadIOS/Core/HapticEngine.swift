// HapticEngine.swift
// PocketPadIOS
// Haptic feedback for trackpad interactions

import UIKit
import CoreHaptics

/// Provides haptic feedback for trackpad gestures.
final class HapticEngine {

    private var engine: CHHapticEngine?
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    var isEnabled = true

    init() {
        prepareGenerators()
        setupCoreHaptics()
    }

    private func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }

    private func setupCoreHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()

            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
        } catch {
            print("Core Haptics setup failed: \(error)")
        }
    }

    // MARK: - Feedback Methods

    /// Light tap feedback for single tap/click
    func tapFeedback() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    /// Medium feedback for right-click
    func rightClickFeedback() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    /// Strong feedback for drag start
    func dragStartFeedback() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred(intensity: 0.6)
    }

    /// Selection-style feedback for scrolling detents
    func scrollFeedback() {
        guard isEnabled else { return }
        selectionFeedback.selectionChanged()
    }

    /// Double-tap feedback
    func doubleTapFeedback() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.impactLight.impactOccurred()
        }
    }

    /// Connection success feedback
    func connectionFeedback() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
    }

    /// Disconnection feedback
    func disconnectionFeedback() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
    }

    /// Error feedback
    func errorFeedback() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
    }

    /// Custom keyboard key tap
    func keyTapFeedback() {
        guard isEnabled else { return }
        impactLight.impactOccurred(intensity: 0.4)
    }
}
