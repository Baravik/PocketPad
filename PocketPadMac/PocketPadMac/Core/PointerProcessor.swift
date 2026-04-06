// PointerProcessor.swift
// PocketPadMac
// Applies acceleration, smoothing, and jitter filtering to pointer input

import Foundation

/// Processes raw input deltas with acceleration curves, smoothing, and jitter rejection.
final class PointerProcessor {

    // MARK: - Configuration

    struct Config {
        var sensitivity: Double = 1.0        // Base sensitivity multiplier (0.1 - 3.0)
        var acceleration: Double = 1.0       // Acceleration factor (0.0 - 2.0)
        var naturalScrolling: Bool = true    // Inverted scroll (Apple default)
        var jitterThreshold: Double = 0.5    // Minimum delta to count as movement
        var smoothingFactor: Double = 0.3    // EMA smoothing (0=no smoothing, 1=max smoothing)
    }

    var config = Config()

    // MARK: - State

    private var lastDeltaX: Double = 0
    private var lastDeltaY: Double = 0
    private var velocityX: Double = 0
    private var velocityY: Double = 0
    private var lastTimestamp: TimeInterval = 0

    // Inertial scroll state
    private var scrollVelocityX: Double = 0
    private var scrollVelocityY: Double = 0
    private var inertialTimer: Timer?

    // MARK: - Cursor Processing

    /// Processes raw touch delta into smoothed, accelerated cursor delta.
    func processCursorDelta(dx rawDX: Double, dy rawDY: Double, timestamp: TimeInterval) -> (dx: Double, dy: Double) {
        // 1. Jitter rejection
        let magnitude = sqrt(rawDX * rawDX + rawDY * rawDY)
        guard magnitude > config.jitterThreshold else {
            return (0, 0)
        }

        // 2. Calculate velocity for acceleration
        let dt = timestamp - lastTimestamp
        let speed: Double
        if dt > 0 && dt < 1.0 {
            speed = magnitude / dt
        } else {
            speed = magnitude * 60 // Assume ~60fps if timing is off
        }

        // 3. Apply acceleration curve
        let acceleratedMagnitude = applyAcceleration(speed: speed, magnitude: magnitude)
        let ratio = acceleratedMagnitude / magnitude

        var dx = rawDX * ratio * config.sensitivity
        var dy = rawDY * ratio * config.sensitivity

        // 4. Exponential Moving Average smoothing
        let alpha = 1.0 - config.smoothingFactor
        dx = alpha * dx + config.smoothingFactor * lastDeltaX
        dy = alpha * dy + config.smoothingFactor * lastDeltaY

        lastDeltaX = dx
        lastDeltaY = dy
        lastTimestamp = timestamp

        return (dx, dy)
    }

    // MARK: - Scroll Processing

    /// Processes raw scroll delta with natural scrolling and momentum.
    func processScrollDelta(dx rawDX: Double, dy rawDY: Double) -> (dx: Double, dy: Double) {
        var dx = rawDX * config.sensitivity * 2.0
        var dy = rawDY * config.sensitivity * 2.0

        if config.naturalScrolling {
            dx = -dx
            dy = -dy
        }

        // Track velocity for inertial scrolling
        scrollVelocityX = dx
        scrollVelocityY = dy

        return (dx, dy)
    }

    /// Starts inertial scrolling after the user lifts fingers.
    func startInertialScroll(onScroll: @escaping (Double, Double) -> Void) {
        stopInertialScroll()

        guard abs(scrollVelocityX) > 0.5 || abs(scrollVelocityY) > 0.5 else { return }

        let decay: Double = 0.95
        let minVelocity: Double = 0.3

        inertialTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            self.scrollVelocityX *= decay
            self.scrollVelocityY *= decay

            if abs(self.scrollVelocityX) < minVelocity && abs(self.scrollVelocityY) < minVelocity {
                timer.invalidate()
                self.inertialTimer = nil
                return
            }

            onScroll(self.scrollVelocityX, self.scrollVelocityY)
        }
    }

    func stopInertialScroll() {
        inertialTimer?.invalidate()
        inertialTimer = nil
        scrollVelocityX = 0
        scrollVelocityY = 0
    }

    // MARK: - Reset

    func reset() {
        lastDeltaX = 0
        lastDeltaY = 0
        velocityX = 0
        velocityY = 0
        lastTimestamp = 0
        stopInertialScroll()
    }

    // MARK: - Acceleration Curve

    /// Custom acceleration curve that provides precise slow movement and fast long-distance travel.
    /// Modeled after macOS pointer acceleration.
    private func applyAcceleration(speed: Double, magnitude: Double) -> Double {
        let accel = config.acceleration

        // Piecewise acceleration: slow speeds get minimal boost, fast speeds get proportional boost
        let normalizedSpeed = speed / 1000.0 // Normalize to reasonable range

        let factor: Double
        if normalizedSpeed < 0.1 {
            // Slow, precise movement: minimal acceleration
            factor = 1.0 + accel * normalizedSpeed * 0.5
        } else if normalizedSpeed < 0.5 {
            // Medium speed: linear ramp
            factor = 1.0 + accel * (0.05 + normalizedSpeed * 1.5)
        } else {
            // Fast movement: strong acceleration
            factor = 1.0 + accel * (0.8 + normalizedSpeed * 2.5)
        }

        return magnitude * factor
    }
}
