// TrackpadTouchView.swift
// PocketPadIOS
// UIKit view that captures raw touches and feeds them to the GestureEngine

import UIKit

protocol TrackpadTouchViewDelegate: AnyObject {
    func trackpadView(_ view: TrackpadTouchView, didRecognize gesture: TrackpadGesture)
    func trackpadView(_ view: TrackpadTouchView, activeFingersChanged count: Int)
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

    override var editingInteractionConfiguration: UIEditingInteractionConfiguration {
        return .none
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
        }
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
        if !isFirstResponder {
            becomeFirstResponder()
        }
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
        trackpadDelegate?.trackpadView(self, activeFingersChanged: touchIndicators.count)

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
        trackpadDelegate?.trackpadView(self, activeFingersChanged: touchIndicators.count)
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

class TrackpadViewController: UIViewController {
    var trackpadView: TrackpadTouchView {
        return view as! TrackpadTouchView
    }

    override func loadView() {
        view = TrackpadTouchView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Dummy pan gesture to seize up to 4 touches, deferring system multitasking
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dummyPan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 4
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        view.addGestureRecognizer(pan)
    }

    @objc private func dummyPan(_ gesture: UIPanGestureRecognizer) {
        // Absorbs touch intent to prevent system hijacking, actual parsing is done inside TrackpadTouchView
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .all
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
}

struct TrackpadSurface: UIViewControllerRepresentable {
    let onGesture: (TrackpadGesture) -> Void
    var onFingerCountChanged: ((Int) -> Void)? = nil
    var tapToClick: Bool = true
    var secondaryClick: Bool = true
    var sensitivity: CGFloat = 1.0
    var cornerRadius: CGFloat = 0

    func makeUIViewController(context: Context) -> TrackpadViewController {
        let vc = TrackpadViewController()
        vc.trackpadView.trackpadDelegate = context.coordinator
        vc.trackpadView.tapToClick = tapToClick
        vc.trackpadView.secondaryClick = secondaryClick
        vc.trackpadView.sensitivity = sensitivity
        vc.trackpadView.layer.cornerRadius = cornerRadius
        vc.trackpadView.layer.masksToBounds = cornerRadius > 0
        return vc
    }

    func updateUIViewController(_ uiViewController: TrackpadViewController, context: Context) {
        context.coordinator.onFingerCountChanged = onFingerCountChanged
        uiViewController.trackpadView.tapToClick = tapToClick
        uiViewController.trackpadView.secondaryClick = secondaryClick
        uiViewController.trackpadView.sensitivity = sensitivity
        uiViewController.trackpadView.layer.cornerRadius = cornerRadius
        uiViewController.trackpadView.layer.masksToBounds = cornerRadius > 0
    }

    func makeCoordinator() -> Coordinator {
        let coord = Coordinator(onGesture: onGesture)
        coord.onFingerCountChanged = onFingerCountChanged
        return coord
    }

    class Coordinator: NSObject, TrackpadTouchViewDelegate {
        let onGesture: (TrackpadGesture) -> Void
        var onFingerCountChanged: ((Int) -> Void)?

        init(onGesture: @escaping (TrackpadGesture) -> Void) {
            self.onGesture = onGesture
        }

        func trackpadView(_ view: TrackpadTouchView, didRecognize gesture: TrackpadGesture) {
            onGesture(gesture)
        }
        
        func trackpadView(_ view: TrackpadTouchView, activeFingersChanged count: Int) {
            onFingerCountChanged?(count)
        }
    }
}
