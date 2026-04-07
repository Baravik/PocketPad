// GestureEngine.swift
// PocketPadIOS
// Multi-touch gesture recognition for trackpad simulation

import UIKit

/// Recognized gesture types
enum TrackpadGesture {
    case move(dx: CGFloat, dy: CGFloat)
    case tap(fingers: Int)
    case doubleTap
    case scroll(dx: CGFloat, dy: CGFloat)
    case scrollEnd
    case dragBegan
    case dragChanged(dx: CGFloat, dy: CGFloat)
    case dragEnded
    case pinch(scale: CGFloat)
    // Advanced system gestures
    case threeFingerSwipe(direction: ThreeFingerSwipeDirection)
    case threeFingerDragBegan
    case threeFingerDragChanged(dx: CGFloat, dy: CGFloat)
    case threeFingerDragEnded
    case fourFingerPinch(closing: Bool)  // closing = Launchpad, opening = Show Desktop
}

/// Direction for three-finger swipes
enum ThreeFingerSwipeDirection {
    case up      // Mission Control
    case down    // App Exposé
    case left    // Switch space left
    case right   // Switch space right
}

protocol GestureEngineDelegate: AnyObject {
    func gestureEngine(_ engine: GestureEngine, didRecognize gesture: TrackpadGesture)
}

/// Processes raw touch events into trackpad gestures.
/// Supports: single-finger move, tap, double-tap, two-finger scroll, long-press drag, pinch.
final class GestureEngine {

    weak var delegate: GestureEngineDelegate?

    // MARK: - Configuration

    var tapToClick = true
    var secondaryClick = true
    var sensitivity: CGFloat = 1.0

    // MARK: - State

    private var activeTouches: [UITouch: CGPoint] = [:]
    private var previousTouchPositions: [UITouch: CGPoint] = [:]
    private var initialTouchPositions: [UITouch: CGPoint] = [:]

    // Tap detection
    private var touchStartTime: TimeInterval = 0
    private var touchStartPosition: CGPoint = .zero
    private var touchCount = 0
    private var lastTapTime: TimeInterval = 0
    private var lastTapPosition: CGPoint = .zero

    // Drag state
    private var isDragging = false
    private var longPressTimer: Timer?
    private let longPressDuration: TimeInterval = 0.35
    private let tapMaxDuration: TimeInterval = 0.25
    private let tapMaxDistance: CGFloat = 12.0
    private let doubleTapMaxInterval: TimeInterval = 0.3

    // Scroll state
    private var isScrolling = false
    private var scrollAccumulatorX: CGFloat = 0
    private var scrollAccumulatorY: CGFloat = 0

    // Three-finger state
    private var threeFingerStartPositions: [UITouch: CGPoint] = [:]
    private var threeFingerAccumulatorX: CGFloat = 0
    private var threeFingerAccumulatorY: CGFloat = 0
    private var isThreeFingerDragging = false
    private var threeFingerSwipeDetected = false
    private let threeFingerSwipeThreshold: CGFloat = 30.0  // min points to trigger swipe
    private let threeFingerDragDelay: TimeInterval = 0.15  // must hold before drag starts
    private var threeFingerStartTime: TimeInterval = 0

    // Four-finger state
    private var fourFingerInitialDistance: CGFloat?
    private var fourFingerPinchDetected = false
    private let fourFingerPinchThreshold: CGFloat = 0.20  // 20% change triggers pinch

    // MARK: - Touch Handling

    func touchesBegan(_ touches: Set<UITouch>, in view: UIView) {
        let wasEmpty = activeTouches.isEmpty
        for touch in touches {
            let location = touch.location(in: view)
            activeTouches[touch] = location
            previousTouchPositions[touch] = location
            initialTouchPositions[touch] = location
        }

        touchCount = activeTouches.count
        if wasEmpty, let firstTouch = touches.first {
            touchStartTime = firstTouch.timestamp
            touchStartPosition = firstTouch.location(in: view)
        }

        // Start long-press timer for drag (single finger only)
        if activeTouches.count == 1 {
            startLongPressTimer()
        } else {
            cancelLongPressTimer()
        }

        // Reset scroll state for two-finger
        if activeTouches.count == 2 {
            isScrolling = true
            scrollAccumulatorX = 0
            scrollAccumulatorY = 0
        }

        // Three-finger tracking — initialize when we reach 3 fingers
        if activeTouches.count == 3 && !isThreeFingerDragging {
            threeFingerStartPositions = activeTouches
            threeFingerAccumulatorX = 0
            threeFingerAccumulatorY = 0
            threeFingerSwipeDetected = false
            threeFingerStartTime = ProcessInfo.processInfo.systemUptime
            isScrolling = false  // Cancel any 2-finger scroll
        }

        // Four-finger tracking — initialize when we reach 4 fingers
        if activeTouches.count >= 4 && fourFingerInitialDistance == nil {
            fourFingerInitialDistance = averagePairDistance(Array(activeTouches.values))
            fourFingerPinchDetected = false
        }
    }

    func touchesMoved(_ touches: Set<UITouch>, in view: UIView) {
        let fingerCount = activeTouches.count

        if fingerCount == 1 {
            // Single finger: cursor movement or drag
            guard let touch = touches.first,
                  let previousPos = previousTouchPositions[touch] else { return }

            let currentPos = touch.location(in: view)
            let dx = (currentPos.x - previousPos.x) * sensitivity
            let dy = (currentPos.y - previousPos.y) * sensitivity

            if isDragging {
                delegate?.gestureEngine(self, didRecognize: .dragChanged(dx: dx, dy: dy))
            } else {
                // Check if we've moved enough to cancel tap
                let totalDist = distance(from: touchStartPosition, to: currentPos)
                if totalDist > tapMaxDistance {
                    cancelLongPressTimer()
                }
                delegate?.gestureEngine(self, didRecognize: .move(dx: dx, dy: dy))
            }

            previousTouchPositions[touch] = currentPos
            activeTouches[touch] = currentPos

        } else if fingerCount == 2 {
            // Two fingers: scroll
            cancelLongPressTimer()
            var totalDX: CGFloat = 0
            var totalDY: CGFloat = 0
            var count: CGFloat = 0

            for touch in touches {
                guard let previousPos = previousTouchPositions[touch] else { continue }
                let currentPos = touch.location(in: view)
                totalDX += currentPos.x - previousPos.x
                totalDY += currentPos.y - previousPos.y
                previousTouchPositions[touch] = currentPos
                activeTouches[touch] = currentPos
                count += 1
            }

            if count > 0 {
                let avgDX = (totalDX / count) * sensitivity
                let avgDY = (totalDY / count) * sensitivity
                scrollAccumulatorX += avgDX
                scrollAccumulatorY += avgDY
                delegate?.gestureEngine(self, didRecognize: .scroll(dx: avgDX, dy: avgDY))
            }
        } else if fingerCount == 3 {
            // Three fingers: swipe or drag
            cancelLongPressTimer()
            var totalDX: CGFloat = 0
            var totalDY: CGFloat = 0
            var count: CGFloat = 0

            for touch in touches {
                guard let previousPos = previousTouchPositions[touch] else { continue }
                let currentPos = touch.location(in: view)
                totalDX += currentPos.x - previousPos.x
                totalDY += currentPos.y - previousPos.y
                previousTouchPositions[touch] = currentPos
                activeTouches[touch] = currentPos
                count += 1
            }

            if count > 0 {
                let avgDX = (totalDX / count) * sensitivity
                let avgDY = (totalDY / count) * sensitivity
                threeFingerAccumulatorX += avgDX
                threeFingerAccumulatorY += avgDY

                // Only detect fast swipe
                if !threeFingerSwipeDetected {
                    let absX = abs(threeFingerAccumulatorX)
                    let absY = abs(threeFingerAccumulatorY)
                    if absX > threeFingerSwipeThreshold || absY > threeFingerSwipeThreshold {
                        threeFingerSwipeDetected = true
                        let direction: ThreeFingerSwipeDirection
                        if absX > absY {
                            direction = threeFingerAccumulatorX > 0 ? .right : .left
                        } else {
                            direction = threeFingerAccumulatorY > 0 ? .down : .up
                        }
                        delegate?.gestureEngine(self, didRecognize: .threeFingerSwipe(direction: direction))
                    }
                }
            }

        } else if fingerCount >= 4 {
            // Four+ fingers: detect pinch
            cancelLongPressTimer()
            let positions = Array(activeTouches.values)
            if positions.count >= 4, let initialDist = fourFingerInitialDistance {
                let currentDist = averagePairDistance(positions)
                let ratio = currentDist / initialDist
                if abs(ratio - 1.0) > fourFingerPinchThreshold && !fourFingerPinchDetected {
                    fourFingerPinchDetected = true
                    let closing = ratio < 1.0  // fingers moving together = Launchpad
                    delegate?.gestureEngine(self, didRecognize: .fourFingerPinch(closing: closing))
                }
            }
            // Still update positions
            for touch in touches {
                let pos = touch.location(in: view)
                previousTouchPositions[touch] = pos
                activeTouches[touch] = pos
            }
        }
    }

    func touchesEnded(_ touches: Set<UITouch>, in view: UIView) {
        let endingFingerCount = touchCount

        // Check for tap
        if let touch = touches.first, let startPos = initialTouchPositions[touch] {
            let elapsed = touch.timestamp - touchStartTime
            let endPos = touch.location(in: view)
            let dist = distance(from: startPos, to: endPos)

            if elapsed < tapMaxDuration && dist < tapMaxDistance && tapToClick {
                // It's a tap
                let now = touch.timestamp

                if endingFingerCount == 1 {
                    // Check for double-tap
                    if now - lastTapTime < doubleTapMaxInterval &&
                       distance(from: lastTapPosition, to: endPos) < tapMaxDistance * 2 {
                        delegate?.gestureEngine(self, didRecognize: .doubleTap)
                        lastTapTime = 0 // Reset to prevent triple-tap
                    } else {
                        // Single tap - delay briefly to check for double tap
                        lastTapTime = now
                        lastTapPosition = endPos
                        DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapMaxInterval) { [weak self] in
                            guard let self = self, self.lastTapTime == now else { return }
                            self.delegate?.gestureEngine(self, didRecognize: .tap(fingers: 1))
                        }
                    }
                } else if endingFingerCount == 2 && secondaryClick {
                    // Two-finger tap = right click
                    let scrollMagnitude = sqrt(scrollAccumulatorX * scrollAccumulatorX + scrollAccumulatorY * scrollAccumulatorY)
                    if scrollMagnitude < 15 { // Only if didn't scroll significantly
                        delegate?.gestureEngine(self, didRecognize: .tap(fingers: 2))
                    }
                } else if endingFingerCount == 3 {
                    // Three-finger tap = middle click
                    let scrollMagnitude = sqrt(threeFingerAccumulatorX * threeFingerAccumulatorX + threeFingerAccumulatorY * threeFingerAccumulatorY)
                    if scrollMagnitude < 15 {
                        delegate?.gestureEngine(self, didRecognize: .tap(fingers: 3))
                    }
                }
            }
        }

        // End drag if active
        if isDragging {
            isDragging = false
            delegate?.gestureEngine(self, didRecognize: .dragEnded)
        }

        // End three-finger drag or detect swipe
        if endingFingerCount == 3 {
            if !threeFingerSwipeDetected {
                // Check if accumulated movement qualifies as a swipe
                let absX = abs(threeFingerAccumulatorX)
                let absY = abs(threeFingerAccumulatorY)
                if absX > threeFingerSwipeThreshold || absY > threeFingerSwipeThreshold {
                    threeFingerSwipeDetected = true
                    let direction: ThreeFingerSwipeDirection
                    if absX > absY {
                        direction = threeFingerAccumulatorX > 0 ? .right : .left
                    } else {
                        direction = threeFingerAccumulatorY > 0 ? .down : .up
                    }
                    delegate?.gestureEngine(self, didRecognize: .threeFingerSwipe(direction: direction))
                }
            }
        }

        // End scroll
        if isScrolling && endingFingerCount == 2 {
            isScrolling = false
            delegate?.gestureEngine(self, didRecognize: .scrollEnd)
        }

        // Clean up ended touches
        for touch in touches {
            activeTouches.removeValue(forKey: touch)
            previousTouchPositions.removeValue(forKey: touch)
        }

        if activeTouches.isEmpty {
            touchCount = 0
            cancelLongPressTimer()
            // Reset multi-finger state
            threeFingerStartPositions.removeAll()
            fourFingerInitialDistance = nil
        }
    }

    func touchesCancelled(_ touches: Set<UITouch>, in view: UIView) {
        if isDragging {
            isDragging = false
            delegate?.gestureEngine(self, didRecognize: .dragEnded)
        }
        if isThreeFingerDragging {
            isThreeFingerDragging = false
            delegate?.gestureEngine(self, didRecognize: .threeFingerDragEnded)
        }
        if isScrolling {
            isScrolling = false
            delegate?.gestureEngine(self, didRecognize: .scrollEnd)
        }
        activeTouches.removeAll()
        previousTouchPositions.removeAll()
        initialTouchPositions.removeAll()
        touchCount = 0
        threeFingerStartPositions.removeAll()
        fourFingerInitialDistance = nil
        fourFingerPinchDetected = false
        threeFingerSwipeDetected = false
        cancelLongPressTimer()
    }

    // MARK: - Long Press (Drag)

    private func startLongPressTimer() {
        cancelLongPressTimer()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressDuration, repeats: false) { [weak self] _ in
            guard let self = self, self.activeTouches.count == 1 else { return }
            self.isDragging = true
            self.delegate?.gestureEngine(self, didRecognize: .dragBegan)
        }
    }

    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    // MARK: - Pinch Detection

    private var lastPinchDistance: CGFloat?

    private func detectPinch(touches: Set<UITouch>, in view: UIView) {
        let touchArray = Array(activeTouches.values)
        guard touchArray.count >= 2 else { return }

        let p1 = touchArray[0]
        let p2 = touchArray[1]
        let currentDistance = distance(from: p1, to: p2)

        if let lastDist = lastPinchDistance {
            let scale = currentDistance / lastDist
            if abs(scale - 1.0) > 0.01 {
                delegate?.gestureEngine(self, didRecognize: .pinch(scale: scale))
            }
        }

        lastPinchDistance = currentDistance

        // Update positions
        for touch in touches {
            let pos = touch.location(in: view)
            previousTouchPositions[touch] = pos
            activeTouches[touch] = pos
        }
    }

    // MARK: - Helpers

    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }

    func reset() {
        activeTouches.removeAll()
        previousTouchPositions.removeAll()
        initialTouchPositions.removeAll()
        isDragging = false
        isScrolling = false
        isThreeFingerDragging = false
        threeFingerSwipeDetected = false
        threeFingerStartPositions.removeAll()
        fourFingerInitialDistance = nil
        fourFingerPinchDetected = false
        touchCount = 0
        lastPinchDistance = nil
        cancelLongPressTimer()
    }

    /// Computes average distance between all pairs of points (for 4-finger pinch detection)
    private func averagePairDistance(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        var totalDist: CGFloat = 0
        var pairCount: CGFloat = 0
        for i in 0..<points.count {
            for j in (i+1)..<points.count {
                totalDist += distance(from: points[i], to: points[j])
                pairCount += 1
            }
        }
        return pairCount > 0 ? totalDist / pairCount : 0
    }
}
