// MacSessionManager.swift
// PocketPadMac
// MultipeerConnectivity host that advertises and accepts connections from iPhones

import MultipeerConnectivity
import Combine
import UserNotifications

/// Manages the Mac side of the MultipeerConnectivity session.
/// Advertises the Mac as a host and processes incoming messages from the iPhone.
final class MacSessionManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectedDeviceName: String = ""
    @Published var lastHeartbeat: Date?
    @Published var remoteBatteryLevel: Float?

    // MARK: - Dependencies

    private let inputInjector = InputInjector()
    private let pointerProcessor = PointerProcessor()

    // MARK: - MultipeerConnectivity

    private let myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?

    // MARK: - Reconnect

    private var reconnectTimer: Timer?
    private let maxReconnectAttempts = 10
    private var reconnectAttempts = 0
    private var shouldAutoReconnect = true

    // Heartbeat monitoring
    private var heartbeatTimer: Timer?
    private let heartbeatTimeout: TimeInterval = 10.0

    // Drag state
    private var isDragging = false

    // MARK: - Settings

    var settings: TrackpadSettings = TrackpadSettings() {
        didSet {
            pointerProcessor.config.sensitivity = settings.sensitivity
            pointerProcessor.config.acceleration = settings.acceleration
            pointerProcessor.config.naturalScrolling = settings.naturalScrolling
        }
    }

    // MARK: - Init

    override init() {
        self.myPeerID = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
        super.init()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Start / Stop

    func startAdvertising() {
        stopAdvertising()

        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: ["version": "\(PocketPadService.protocolVersion)"],
            serviceType: PocketPadService.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        connectionState = .discovering
        startHeartbeatMonitor()
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        session?.disconnect()
        session = nil
        connectionState = .disconnected
        connectedDeviceName = ""
        stopReconnectTimer()
        stopHeartbeatMonitor()
    }

    // MARK: - Message Processing

    private func processMessage(_ data: Data) {
        guard let envelope = PocketPadCoder.decodeEnvelope(from: data) else { return }

        switch envelope.type {
        case .cursorMove:
            guard let msg = PocketPadCoder.decodePayload(CursorMoveMessage.self, from: envelope.payload) else { return }
            let processed = pointerProcessor.processCursorDelta(dx: msg.deltaX, dy: msg.deltaY, timestamp: msg.timestamp)
            inputInjector.moveCursor(deltaX: processed.dx, deltaY: processed.dy)

        case .scroll:
            guard let msg = PocketPadCoder.decodePayload(ScrollMessage.self, from: envelope.payload) else { return }
            let processed = pointerProcessor.processScrollDelta(dx: msg.deltaX, dy: msg.deltaY)
            inputInjector.scroll(deltaX: processed.dx, deltaY: processed.dy)

        case .click:
            guard let msg = PocketPadCoder.decodePayload(ClickMessage.self, from: envelope.payload) else { return }
            handleClick(msg)

        case .drag:
            guard let msg = PocketPadCoder.decodePayload(DragMessage.self, from: envelope.payload) else { return }
            handleDrag(msg)

        case .keyboardText:
            guard let msg = PocketPadCoder.decodePayload(KeyboardTextMessage.self, from: envelope.payload) else { return }
            inputInjector.typeText(msg.text)

        case .specialKey:
            guard let msg = PocketPadCoder.decodePayload(SpecialKeyMessage.self, from: envelope.payload) else { return }
            inputInjector.sendSpecialKey(msg.key.rawValue, isDown: msg.isDown, modifiers: msg.modifiers)

        case .keyboardShortcut:
            guard let msg = PocketPadCoder.decodePayload(KeyboardShortcutMessage.self, from: envelope.payload) else { return }
            inputInjector.sendKeyboardShortcut(key: msg.key, modifiers: msg.modifiers)

        case .systemGesture:
            guard let msg = PocketPadCoder.decodePayload(SystemGestureMessage.self, from: envelope.payload) else { return }
            inputInjector.performSystemGesture(msg.gesture, deltaX: msg.deltaX, deltaY: msg.deltaY)

        case .heartbeat:
            guard let msg = PocketPadCoder.decodePayload(HeartbeatMessage.self, from: envelope.payload) else { return }
            DispatchQueue.main.async {
                self.lastHeartbeat = Date()
                self.remoteBatteryLevel = msg.batteryLevel
            }

        case .capabilities:
            guard let _ = PocketPadCoder.decodePayload(DeviceCapabilities.self, from: envelope.payload) else { return }
            // Store capabilities for future use
            break

        case .reconnect:
            // iPhone is requesting reconnect
            break

        case .disconnect:
            // iPhone is disconnecting gracefully
            DispatchQueue.main.async {
                self.connectionState = .disconnected
                self.connectedDeviceName = ""
            }

        case .settings:
            guard let s = PocketPadCoder.decodePayload(TrackpadSettings.self, from: envelope.payload) else { return }
            DispatchQueue.main.async {
                self.settings = s
            }
        }
    }

    private func handleClick(_ msg: ClickMessage) {
        let button = msg.button
        switch msg.action {
        case .single:
            inputInjector.click(button: button)
        case .double:
            inputInjector.doubleClick(button: button)
        case .down:
            inputInjector.mouseDown(button: button)
        case .up:
            inputInjector.mouseUp(button: button)
        }
    }

    private func handleDrag(_ msg: DragMessage) {
        switch msg.phase {
        case .began:
            isDragging = true
            inputInjector.mouseDown(button: msg.button)
        case .changed:
            let processed = pointerProcessor.processCursorDelta(dx: msg.deltaX, dy: msg.deltaY, timestamp: msg.timestamp)
            inputInjector.dragMove(deltaX: processed.dx, deltaY: processed.dy, button: msg.button)
        case .ended:
            isDragging = false
            inputInjector.mouseUp(button: msg.button)
        }
    }

    // MARK: - Send Settings to iPhone

    func sendSettings() {
        guard let session = session, let peer = session.connectedPeers.first,
              let data = PocketPadCoder.settings(settings) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    // MARK: - Reconnect Logic

    private func attemptReconnect() {
        guard shouldAutoReconnect, reconnectAttempts < maxReconnectAttempts else {
            connectionState = .disconnected
            return
        }

        connectionState = .reconnecting
        reconnectAttempts += 1

        // Re-advertise to allow the iPhone to reconnect
        startAdvertising()
    }

    private func startReconnectTimer() {
        stopReconnectTimer()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.attemptReconnect()
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    // MARK: - Heartbeat Monitor

    private func startHeartbeatMonitor() {
        stopHeartbeatMonitor()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, self.connectionState == .connected else { return }
            if let last = self.lastHeartbeat, Date().timeIntervalSince(last) > self.heartbeatTimeout {
                // Connection might be dead
                self.connectionState = .reconnecting
            }
        }
    }

    private func stopHeartbeatMonitor() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
}

// MARK: - MCSessionDelegate

extension MacSessionManager: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.connectionState = .connected
                self.connectedDeviceName = peerID.displayName
                self.reconnectAttempts = 0
                self.pointerProcessor.reset()
                self.isDragging = false
                
                let content = UNMutableNotificationContent()
                content.title = "Device Connected"
                content.body = "PocketPad connected to \(peerID.displayName)"
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            case .connecting:
                self.connectionState = .connecting
            case .notConnected:
                if self.connectionState == .connected {
                    // Was connected, now lost connection
                    self.connectionState = .reconnecting
                    self.connectedDeviceName = ""
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
        processMessage(data)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MacSessionManager: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept connections (the pairing is implicit for v1)
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }
}
