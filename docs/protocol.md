# PocketPad — Wire Protocol Specification

## Transport

| Property | Value |
|----------|-------|
| Layer | MultipeerConnectivity (MCSession) |
| Discovery | Bonjour, service type `pocketpad-ctrl` |
| Encryption | `.required` (MCEncryptionPreference) |
| Transports | Wi-Fi, Bluetooth |

## Message Format

All messages use a **JSON envelope**:

```json
{
  "type": <UInt8>,
  "payload": <Base64-encoded JSON>
}
```

The `type` field identifies the message, and `payload` contains the type-specific data encoded as JSON then wrapped in the envelope as `Data`.

## Message Types

| Type | Code | Transport | Description |
|------|------|-----------|-------------|
| `cursorMove` | 1 | Unreliable | Cursor delta movement |
| `scroll` | 2 | Unreliable | Scroll wheel delta |
| `click` | 3 | Reliable | Mouse button click |
| `drag` | 4 | Mixed* | Drag gesture |
| `keyboardText` | 5 | Reliable | Unicode text string |
| `specialKey` | 6 | Reliable | Special key event |
| `keyboardShortcut` | 7 | Reliable | Key + modifiers shortcut |
| `heartbeat` | 10 | Unreliable | Keep-alive + battery |
| `reconnect` | 11 | Reliable | Reconnect request |
| `capabilities` | 12 | Reliable | Device capabilities |
| `disconnect` | 13 | Reliable | Graceful disconnect |
| `settings` | 14 | Reliable | Settings sync |

*Drag: `began`/`ended` = reliable, `changed` = unreliable for latency

## Payload Schemas

### CursorMove (1)
```json
{ "deltaX": 12.5, "deltaY": -3.2, "timestamp": 1234567.89 }
```

### Scroll (2)
```json
{ "deltaX": 0, "deltaY": -15.0, "isInertial": false, "timestamp": 1234567.89 }
```

### Click (3)
```json
{ "button": 0, "action": 2, "timestamp": 1234567.89 }
```
- Button: 0=left, 1=right, 2=middle
- Action: 0=down, 1=up, 2=single, 3=double

### Drag (4)
```json
{ "phase": 1, "deltaX": 5.0, "deltaY": -2.0, "button": 0, "timestamp": 1234567.89 }
```
- Phase: 0=began, 1=changed, 2=ended

### KeyboardText (5)
```json
{ "text": "שלום Hello 🎉", "timestamp": 1234567.89 }
```

### SpecialKey (6)
```json
{ "key": 36, "isDown": true, "modifiers": { "rawValue": 8 }, "timestamp": 1234567.89 }
```
Key values are macOS virtual key codes. Modifiers: 1=shift, 2=control, 4=option, 8=command.

### KeyboardShortcut (7)
```json
{ "key": "c", "modifiers": { "rawValue": 8 }, "timestamp": 1234567.89 }
```

### Heartbeat (10)
```json
{ "deviceName": "iPhone", "batteryLevel": 0.85, "timestamp": 1234567.89 }
```

### DeviceCapabilities (12)
```json
{
  "deviceName": "iPhone 15 Pro",
  "protocolVersion": 1,
  "supportsHaptics": true,
  "supportsPinchZoom": true,
  "supportsKeyboard": true,
  "screenWidth": 393.0,
  "screenHeight": 852.0
}
```

### TrackpadSettings (14)
```json
{
  "sensitivity": 1.0,
  "acceleration": 1.0,
  "naturalScrolling": true,
  "tapToClick": true,
  "secondaryClick": true,
  "hapticFeedback": true
}
```

## Timing

| Metric | Target |
|--------|--------|
| Heartbeat interval | 3 seconds |
| Heartbeat timeout | 10 seconds |
| Reconnect delay | 2-10s exponential backoff |
| Max reconnect attempts | 15 |
