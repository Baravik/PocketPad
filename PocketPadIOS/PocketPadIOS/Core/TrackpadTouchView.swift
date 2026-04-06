// TrackpadTouchView.swift
// PocketPadIOS
// UIKit view that captures raw touches and feeds them to the GestureEngine

import UIKit

protocol TrackpadTouchViewDelegate: AnyObject {
    func trackpadView(_ view: TrackpadTouchView, didRecognize gesture: TrackpadGesture)
}

/// A UIKit view optimized for low-latency multi-touch capture.
/// This is embedded in the SwiftUI hierarchy via UIViewRepresentable.
final class TrackpadTouchView: UIView {

    weak var trackpadDelegate: TrackpadTouchViewDelegate?

    private let gestureEngine = GestureEngine()

    // Visual feedback
    private var touchIndicators: [UITouch: CALayer] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isMultipleTouchEnabled = true
        isExclusiveTouch = true
        isUserInteractionEnabled = true
        backgroundColor = .clear
        gestureEngine.delegate = self
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        // Disable system gesture recognizers on all parent views
        // that intercept 3-finger touches (undo/redo/paste toolbar)
        disableSystemGestureRecognizers()
    }

    /// Walk up the view hierarchy and disable any UIKit system gesture recognizers
    /// that would steal 3-finger and 4-finger touches from us.
    private func disableSystemGestureRecognizers() {
        var current: UIView? = superview
        while let view = current {
            if let recognizers = view.gestureRecognizers {
                for recognizer in recognizers {
                    let typeName = String(describing: type(of: recognizer))
                    // Disable system text interaction and edit gesture recognizers
                    if typeName.contains("SystemGesture") ||
                       typeName.contains("TextInteraction") ||
                       typeName.contains("EditGesture") ||
                       typeName.contains("UISwipe") ||
                       typeName.contains("ThreeFingers") {
                        recognizer.isEnabled = false
                    }
                    // Let all recognizers know we want to handle touches simultaneously
                    recognizer.delaysTouchesBegan = false
                    recognizer.cancelsTouchesInView = false
                }
            }
            current = view.superview
        }
    }

    // Block ALL external gesture recognizers from intercepting our touches
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    // MARK: - Configuration

    var tapToClick: Bool {
        get { gestureEngine.tapToClick }
        set { gestureEngine.tapToClick = newValue }
    }

    var secondaryClick: Bool {
        get { gestureEngine.secondaryClick }
        set { gestureEngine.secondaryClick = newValue }
    }

    var sensitivity: CGFloat {
        get { gestureEngine.sensitivity }
        set { gestureEngine.sensitivity = newValue }
    }

    // MARK: - Touch Events

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        gestureEngine.touchesBegan(touches, in: self)
        for touch in touches {
            addTouchIndicator(for: touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Process coalesced touches for better accuracy
        if let event = event {
            for touch in touches {
                if let coalesced = event.coalescedTouches(for: touch), coalesced.count > 1 {
                    // Use the last coalesced touch for the final position
                    // but process intermediate ones for smoother movement
                    for coalescedTouch in coalesced {
                        updateTouchIndicator(for: coalescedTouch)
                    }
                }
            }
        }
        gestureEngine.touchesMoved(touches, in: self)
        for touch in touches {
            updateTouchIndicator(for: touch)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        gestureEngine.touchesEnded(touches, in: self)
        for touch in touches {
            removeTouchIndicator(for: touch)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        gestureEngine.touchesCancelled(touches, in: self)
        for touch in touches {
            removeTouchIndicator(for: touch)
        }
    }

    // MARK: - Visual Touch Indicators

    private func addTouchIndicator(for touch: UITouch) {
        let location = touch.location(in: self)
        let indicator = CALayer()
        indicator.frame = CGRect(x: location.x - 20, y: location.y - 20, width: 40, height: 40)
        indicator.cornerRadius = 20
        indicator.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15).cgColor
        indicator.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        indicator.borderWidth = 1.5

        layer.addSublayer(indicator)
        touchIndicators[touch] = indicator

        // Animate in
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        indicator.transform = CATransform3DMakeScale(1.2, 1.2, 1)
        CATransaction.commit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.15)
            indicator.transform = CATransform3DIdentity
            CATransaction.commit()
        }
    }

    private func updateTouchIndicator(for touch: UITouch) {
        guard let indicator = touchIndicators[touch] else { return }
        let location = touch.location(in: self)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        indicator.position = location
        CATransaction.commit()
    }

    private func removeTouchIndicator(for touch: UITouch) {
        guard let indicator = touchIndicators.removeValue(forKey: touch) else { return }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        indicator.opacity = 0
        indicator.transform = CATransform3DMakeScale(0.5, 0.5, 1)
        CATransaction.commit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            indicator.removeFromSuperlayer()
        }
    }
}

// MARK: - GestureEngineDelegate

extension TrackpadTouchView: GestureEngineDelegate {
    func gestureEngine(_ engine: GestureEngine, didRecognize gesture: TrackpadGesture) {
        trackpadDelegate?.trackpadView(self, didRecognize: gesture)
    }
}

// MARK: - SwiftUI Bridge

import SwiftUI

struct TrackpadSurface: UIViewRepresentable {
    let onGesture: (TrackpadGesture) -> Void
    var tapToClick: Bool = true
    var secondaryClick: Bool = true
    var sensitivity: CGFloat = 1.0

    func makeUIView(context: Context) -> TrackpadTouchView {
        let view = TrackpadTouchView()
        view.trackpadDelegate = context.coordinator
        view.tapToClick = tapToClick
        view.secondaryClick = secondaryClick
        view.sensitivity = sensitivity
        return view
    }

    func updateUIView(_ uiView: TrackpadTouchView, context: Context) {
        uiView.tapToClick = tapToClick
        uiView.secondaryClick = secondaryClick
        uiView.sensitivity = sensitivity
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onGesture: onGesture)
    }

    class Coordinator: NSObject, TrackpadTouchViewDelegate {
        let onGesture: (TrackpadGesture) -> Void

        init(onGesture: @escaping (TrackpadGesture) -> Void) {
            self.onGesture = onGesture
        }

        func trackpadView(_ view: TrackpadTouchView, didRecognize gesture: TrackpadGesture) {
            onGesture(gesture)
        }
    }
}
