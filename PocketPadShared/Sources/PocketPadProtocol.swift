// PocketPadProtocol.swift
// PocketPadShared
// Core protocol definitions for PocketPad communication

import Foundation

// MARK: - Service Identity
public enum PocketPadService {
    public static let serviceType = "pocketpad-ctrl"
    public static let protocolVersion: UInt16 = 1
}

// MARK: - Message Types
public enum MessageType: UInt8, Codable {
    case cursorMove       = 1
    case scroll           = 2
    case click            = 3
    case drag             = 4
    case keyboardText     = 5
    case specialKey       = 6
    case keyboardShortcut = 7
    case systemGesture    = 8
    case heartbeat        = 10
    case reconnect        = 11
    case capabilities     = 12
    case disconnect       = 13
    case settings         = 14
}

// MARK: - System Gesture Types
public enum SystemGestureType: UInt8, Codable {
    case missionControl    = 0
    case appExpose         = 1
    case switchSpaceLeft   = 2
    case switchSpaceRight  = 3
    case launchpad         = 4
    case showDesktop       = 5
    case zoomIn            = 6
    case zoomOut           = 7
    case threeFingerDragBegan  = 10
    case threeFingerDragMoved  = 11
    case threeFingerDragEnded  = 12
}

// MARK: - Swipe Direction
public enum SwipeDirection: UInt8, Codable {
    case up    = 0
    case down  = 1
    case left  = 2
    case right = 3
}

// MARK: - Mouse Button
public enum MouseButton: UInt8, Codable {
    case left   = 0
    case right  = 1
    case middle = 2
}

// MARK: - Click Type
public enum ClickAction: UInt8, Codable {
    case down   = 0
    case up     = 1
    case single = 2
    case double = 3
}

// MARK: - Drag Phase
public enum DragPhase: UInt8, Codable {
    case began   = 0
    case changed = 1
    case ended   = 2
}

// MARK: - Special Keys
public enum SpecialKey: UInt16, Codable, CaseIterable {
    case enter      = 36
    case tab        = 48
    case delete     = 51
    case escape     = 53
    case command    = 55
    case shift      = 56
    case capsLock   = 57
    case option     = 58
    case control    = 59
    case arrowLeft  = 123
    case arrowRight = 124
    case arrowDown  = 125
    case arrowUp    = 126
    case space      = 49
    case forwardDelete = 117
    case home       = 115
    case end        = 119
    case pageUp     = 116
    case pageDown   = 121
    case f1         = 122
    case f2         = 120
    case f3         = 99
    case f4         = 118
    case f5         = 96
    case f6         = 97
    case f7         = 98
    case f8         = 100
    case f9         = 101
    case f10        = 109
    case f11        = 103
    case f12        = 111
}

// MARK: - Modifier Flags
public struct ModifierFlags: OptionSet, Codable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let shift   = ModifierFlags(rawValue: 1 << 0)
    public static let control = ModifierFlags(rawValue: 1 << 1)
    public static let option  = ModifierFlags(rawValue: 1 << 2)
    public static let command = ModifierFlags(rawValue: 1 << 3)
}

// MARK: - Protocol Messages
public struct CursorMoveMessage: Codable {
    public let deltaX: Double
    public let deltaY: Double
    public let timestamp: TimeInterval

    public init(deltaX: Double, deltaY: Double, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.timestamp = timestamp
    }
}

public struct ScrollMessage: Codable {
    public let deltaX: Double
    public let deltaY: Double
    public let isInertial: Bool
    public let timestamp: TimeInterval

    public init(deltaX: Double, deltaY: Double, isInertial: Bool = false, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.isInertial = isInertial
        self.timestamp = timestamp
    }
}

public struct ClickMessage: Codable {
    public let button: MouseButton
    public let action: ClickAction
    public let timestamp: TimeInterval

    public init(button: MouseButton, action: ClickAction, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.button = button
        self.action = action
        self.timestamp = timestamp
    }
}

public struct DragMessage: Codable {
    public let phase: DragPhase
    public let deltaX: Double
    public let deltaY: Double
    public let button: MouseButton
    public let timestamp: TimeInterval

    public init(phase: DragPhase, deltaX: Double, deltaY: Double, button: MouseButton = .left, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.phase = phase
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.button = button
        self.timestamp = timestamp
    }
}

public struct KeyboardTextMessage: Codable {
    public let text: String
    public let timestamp: TimeInterval

    public init(text: String, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.text = text
        self.timestamp = timestamp
    }
}

public struct SpecialKeyMessage: Codable {
    public let key: SpecialKey
    public let isDown: Bool
    public let modifiers: ModifierFlags
    public let timestamp: TimeInterval

    public init(key: SpecialKey, isDown: Bool = true, modifiers: ModifierFlags = [], timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.key = key
        self.isDown = isDown
        self.modifiers = modifiers
        self.timestamp = timestamp
    }
}

public struct KeyboardShortcutMessage: Codable {
    public let key: String
    public let modifiers: ModifierFlags
    public let timestamp: TimeInterval

    public init(key: String, modifiers: ModifierFlags, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.key = key
        self.modifiers = modifiers
        self.timestamp = timestamp
    }
}

public struct SystemGestureMessage: Codable {
    public let gesture: SystemGestureType
    public let deltaX: Double
    public let deltaY: Double
    public let timestamp: TimeInterval

    public init(gesture: SystemGestureType, deltaX: Double = 0, deltaY: Double = 0, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.gesture = gesture
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.timestamp = timestamp
    }
}

public struct HeartbeatMessage: Codable {
    public let deviceName: String
    public let batteryLevel: Float?
    public let timestamp: TimeInterval

    public init(deviceName: String, batteryLevel: Float? = nil, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.deviceName = deviceName
        self.batteryLevel = batteryLevel
        self.timestamp = timestamp
    }
}

public struct DeviceCapabilities: Codable {
    public let deviceName: String
    public let protocolVersion: UInt16
    public let supportsHaptics: Bool
    public let supportsPinchZoom: Bool
    public let supportsKeyboard: Bool
    public let screenWidth: Double
    public let screenHeight: Double

    public init(deviceName: String, protocolVersion: UInt16 = PocketPadService.protocolVersion, supportsHaptics: Bool = true, supportsPinchZoom: Bool = true, supportsKeyboard: Bool = true, screenWidth: Double, screenHeight: Double) {
        self.deviceName = deviceName
        self.protocolVersion = protocolVersion
        self.supportsHaptics = supportsHaptics
        self.supportsPinchZoom = supportsPinchZoom
        self.supportsKeyboard = supportsKeyboard
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
    }
}

public struct TrackpadSettings: Codable {
    public var sensitivity: Double
    public var acceleration: Double
    public var naturalScrolling: Bool
    public var tapToClick: Bool
    public var secondaryClick: Bool
    public var hapticFeedback: Bool

    public init(sensitivity: Double = 1.0, acceleration: Double = 1.0, naturalScrolling: Bool = true, tapToClick: Bool = true, secondaryClick: Bool = true, hapticFeedback: Bool = true) {
        self.sensitivity = sensitivity
        self.acceleration = acceleration
        self.naturalScrolling = naturalScrolling
        self.tapToClick = tapToClick
        self.secondaryClick = secondaryClick
        self.hapticFeedback = hapticFeedback
    }
}

// MARK: - Envelope (Wire Format)
public struct PocketPadEnvelope: Codable {
    public let type: MessageType
    public let payload: Data

    public init(type: MessageType, payload: Data) {
        self.type = type
        self.payload = payload
    }
}

// MARK: - Encoding / Decoding Helpers
public enum PocketPadCoder {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    public static func encode<T: Encodable>(type: MessageType, message: T) -> Data? {
        guard let payload = try? encoder.encode(message) else { return nil }
        let envelope = PocketPadEnvelope(type: type, payload: payload)
        return try? encoder.encode(envelope)
    }

    public static func decodeEnvelope(from data: Data) -> PocketPadEnvelope? {
        return try? decoder.decode(PocketPadEnvelope.self, from: data)
    }

    public static func decodePayload<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        return try? decoder.decode(T.self, from: data)
    }

    // Convenience builders
    public static func cursorMove(dx: Double, dy: Double) -> Data? {
        encode(type: .cursorMove, message: CursorMoveMessage(deltaX: dx, deltaY: dy))
    }

    public static func scroll(dx: Double, dy: Double, inertial: Bool = false) -> Data? {
        encode(type: .scroll, message: ScrollMessage(deltaX: dx, deltaY: dy, isInertial: inertial))
    }

    public static func click(button: MouseButton, action: ClickAction) -> Data? {
        encode(type: .click, message: ClickMessage(button: button, action: action))
    }

    public static func drag(phase: DragPhase, dx: Double, dy: Double, button: MouseButton = .left) -> Data? {
        encode(type: .drag, message: DragMessage(phase: phase, deltaX: dx, deltaY: dy, button: button))
    }

    public static func keyboardText(_ text: String) -> Data? {
        encode(type: .keyboardText, message: KeyboardTextMessage(text: text))
    }

    public static func specialKey(_ key: SpecialKey, isDown: Bool = true, modifiers: ModifierFlags = []) -> Data? {
        encode(type: .specialKey, message: SpecialKeyMessage(key: key, isDown: isDown, modifiers: modifiers))
    }

    public static func keyboardShortcut(key: String, modifiers: ModifierFlags) -> Data? {
        encode(type: .keyboardShortcut, message: KeyboardShortcutMessage(key: key, modifiers: modifiers))
    }

    public static func heartbeat(deviceName: String, battery: Float? = nil) -> Data? {
        encode(type: .heartbeat, message: HeartbeatMessage(deviceName: deviceName, batteryLevel: battery))
    }

    public static func capabilities(_ caps: DeviceCapabilities) -> Data? {
        encode(type: .capabilities, message: caps)
    }

    public static func settings(_ settings: TrackpadSettings) -> Data? {
        encode(type: .settings, message: settings)
    }

    public static func systemGesture(_ gesture: SystemGestureType, dx: Double = 0, dy: Double = 0) -> Data? {
        encode(type: .systemGesture, message: SystemGestureMessage(gesture: gesture, deltaX: dx, deltaY: dy))
    }
}
