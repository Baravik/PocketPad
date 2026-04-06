// iOSSessionManager.swift
// PocketPadIOS
// MultipeerConnectivity browser that discovers and connects to Mac hosts

import Foundation
import MultipeerConnectivity
import UIKit
import Combine

/// Manages the iPhone side of MultipeerConnectivity.
/// Discovers nearby Macs running PocketPad and sends gesture/keyboard input.
final class iOSSessionManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectedMacName: String = ""
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var settings: TrackpadSettings = TrackpadSettings()

    // MARK: - MultipeerConnectivity

    private let myPeerID: MCPeerID
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?

    // MARK: - Reconnect

    private var reconnectTimer: Timer?
    private var lastConnectedPeerName: String?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 15
    var autoReconnect = true

    // Heartbeat
    private var heartbeatTimer: Timer?
    private let heartbeatInterval: TimeInterval = 3.0

    // MARK: - Init

    override init() {
        self.myPeerID = MCPeerID(displayName: UIDevice.current.name)
        super.init()
    }

    // MARK: - Start / Stop

    func startBrowsing() {
        stopBrowsing()

        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: PocketPadService.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser

        connectionState = .discovering
    }

    func stopBrowsing() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session?.disconnect()
        session = nil
        connectionState = .disconnected
        connectedMacName = ""
        discoveredPeers.removeAll()
        stopReconnectTimer()
    }

    /// Connect to a specific discovered Mac
    func connect(to peer: MCPeerID) {
        guard let session = session, let browser = browser else { return }
        connectionState = .connecting

        // Send device capabilities as context
        let caps = DeviceCapabilities(
            deviceName: UIDevice.current.name,
            supportsHaptics: true,
            supportsPinchZoom: true,
            supportsKeyboard: true,
            screenWidth: Double(UIScreen.main.bounds.width),
            screenHeight: Double(UIScreen.main.bounds.height)
        )
        let context = try? JSONEncoder().encode(caps)

        browser.invitePeer(peer, to: session, withContext: context, timeout: 10)
    }

    // MARK: - Send Data

    func send(_ data: Data, reliable: Bool = true) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: reliable ? .reliable : .unreliable)
        } catch {
            // Silently handle send errors; the heartbeat/reconnect will catch dead connections
        }
    }

    // Convenience methods
    func sendCursorMove(dx: Double, dy: Double) {
        guard let data = PocketPadCoder.cursorMove(dx: dx, dy: dy) else { return }
        send(data, reliable: false) // Use unreliable for low latency cursor moves
    }

    func sendScroll(dx: Double, dy: Double, inertial: Bool = false) {
        guard let data = PocketPadCoder.scroll(dx: dx, dy: dy, inertial: inertial) else { return }
        send(data, reliable: false)
    }

    func sendClick(button: MouseButton, action: ClickAction) {
        guard let data = PocketPadCoder.click(button: button, action: action) else { return }
        send(data, reliable: true)
    }

    func sendDrag(phase: DragPhase, dx: Double, dy: Double) {
        guard let data = PocketPadCoder.drag(phase: phase, dx: dx, dy: dy) else { return }
        send(data, reliable: phase == .changed ? false : true)
    }

    func sendKeyboardText(_ text: String) {
        guard let data = PocketPadCoder.keyboardText(text) else { return }
        send(data, reliable: true)
    }

    func sendSpecialKey(_ key: SpecialKey, isDown: Bool = true, modifiers: ModifierFlags = []) {
        guard let data = PocketPadCoder.specialKey(key, isDown: isDown, modifiers: modifiers) else { return }
        send(data, reliable: true)
    }

    func sendKeyboardShortcut(key: String, modifiers: ModifierFlags) {
        guard let data = PocketPadCoder.keyboardShortcut(key: key, modifiers: modifiers) else { return }
        send(data, reliable: true)
    }

    func sendSystemGesture(_ gesture: SystemGestureType, dx: Double = 0, dy: Double = 0) {
        guard let data = PocketPadCoder.systemGesture(gesture, dx: dx, dy: dy) else { return }
        // Use reliable for discrete gestures, unreliable for continuous drag moves
        let reliable = gesture != .threeFingerDragMoved
        send(data, reliable: reliable)
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            UIDevice.current.isBatteryMonitoringEnabled = true
            let battery = UIDevice.current.batteryLevel
            guard let data = PocketPadCoder.heartbeat(deviceName: UIDevice.current.name, battery: battery >= 0 ? battery : nil) else { return }
            self.send(data, reliable: false)
        }
    }

    // MARK: - Reconnect Logic

    private func attemptReconnect() {
        guard autoReconnect, reconnectAttempts < maxReconnectAttempts else {
            connectionState = .disconnected
            return
        }

        connectionState = .reconnecting
        reconnectAttempts += 1

        // Restart browsing to find the Mac again
        startBrowsing()
    }

    private func startReconnectTimer() {
        stopReconnectTimer()
        let delay = min(Double(reconnectAttempts + 1) * 2.0, 10.0) // Exponential backoff up to 10s
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.attemptReconnect()
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

// MARK: - MCSessionDelegate

extension iOSSessionManager: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.connectionState = .connected
                self.connectedMacName = peerID.displayName
                self.lastConnectedPeerName = peerID.displayName
                self.reconnectAttempts = 0
                self.stopReconnectTimer()
                self.startHeartbeat()
                // Send capabilities
                if let data = PocketPadCoder.capabilities(DeviceCapabilities(
                    deviceName: UIDevice.current.name,
                    screenWidth: Double(UIScreen.main.bounds.width),
                    screenHeight: Double(UIScreen.main.bounds.height)
                )) {
                    self.send(data)
                }

            case .connecting:
                self.connectionState = .connecting

            case .notConnected:
                self.heartbeatTimer?.invalidate()
                self.heartbeatTimer = nil
                if self.connectionState == .connected {
                    self.connectedMacName = ""
                    self.startReconnectTimer()
                } else {
                    self.connectionState = .disconnected
                }

            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle settings updates from Mac
        guard let envelope = PocketPadCoder.decodeEnvelope(from: data) else { return }
        if envelope.type == .settings {
            if let newSettings = PocketPadCoder.decodePayload(TrackpadSettings.self, from: envelope.payload) {
                DispatchQueue.main.async {
                    self.settings = newSettings
                }
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate

extension iOSSessionManager: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(where: { $0.displayName == peerID.displayName }) {
                self.discoveredPeers.append(peerID)
            }

            // Auto-connect if we were previously connected to this Mac (reconnect scenario)
            if let lastPeer = self.lastConnectedPeerName, lastPeer == peerID.displayName,
               self.connectionState == .reconnecting || self.connectionState == .discovering {
                self.connect(to: peerID)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0.displayName == peerID.displayName }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }
}
