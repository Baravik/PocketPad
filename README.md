# PocketPad

<p align="center">
  <b>Turn your iPhone into a high-quality wireless trackpad for your Mac.</b>
</p>

---

## Overview

PocketPad consists of two native apps that work together:
- **PocketPad iOS** — iPhone app with a multi-touch trackpad surface, keyboard input, and gesture recognition
- **PocketPad Mac** — macOS companion app that receives input and injects cursor/keyboard events

Communication uses **MultipeerConnectivity** over local Wi-Fi/Bluetooth with encryption. No cloud, no internet required.

## Features

### Trackpad
- Smooth cursor movement with acceleration curves
- Single tap → left click
- Two-finger tap → right click  
- Two-finger scroll with inertial momentum
- Long-press drag
- Double-tap → double-click
- Pinch-to-zoom (Ctrl+scroll fallback)
- Jitter rejection and EMA smoothing
- Configurable sensitivity and acceleration
- Portrait and landscape orientations

### Keyboard
- Full multilingual text input (Hebrew, English, emoji, etc.)
- Special keys: Enter, Delete, Tab, Escape, Arrows, Home/End, Page Up/Down, F-keys
- Modifier toolbar: ⌘ Cmd, ⌥ Option, ⌃ Control, ⇧ Shift
- Shortcut bar: Cmd-C, Cmd-V, Cmd-Z, Cmd-A, Cmd-S, Cmd-Tab, Cmd-Space (Spotlight), Cmd-W, Cmd-Q
- Landscape split view with trackpad + keyboard side-by-side

### Connection
- Auto-discovery via Bonjour/MultipeerConnectivity
- Encrypted sessions (`.required`)
- Automatic reconnect with exponential backoff
- Heartbeat monitoring
- Battery level reporting

### Polish
- Dark mode / Light mode (system-following)
- Haptic feedback for all interactions
- Onboarding flows for both apps
- Privacy policy (local-only, no analytics)

---

## Requirements

| Component | Minimum |
|-----------|---------|
| iPhone | iOS 16.0+ |
| Mac | macOS 13.0+ (Ventura) |
| Xcode | 15.0+ |
| Both devices | Same local network or Bluetooth range |

---

## Project Structure

```
Controller/
├── PocketPadShared/          # Shared protocol library
│   ├── Package.swift
│   └── Sources/
│       ├── PocketPadProtocol.swift    # Message types, encoding
│       └── ConnectionState.swift       # Connection state enum
│
├── PocketPadMac/             # macOS companion app
│   ├── PocketPadMac.xcodeproj/
│   └── PocketPadMac/
│       ├── App/              # App entry point
│       ├── Core/             # InputInjector, PointerProcessor, PermissionManager
│       ├── Networking/       # MacSessionManager (MC host)
│       ├── Settings/         # MacSettingsManager
│       ├── Views/            # MenuBar, MainWindow, Settings, Onboarding
│       ├── Assets.xcassets/
│       ├── Info.plist
│       └── PocketPadMac.entitlements
│
├── PocketPadIOS/             # iPhone trackpad app
│   ├── PocketPadIOS.xcodeproj/
│   └── PocketPadIOS/
│       ├── App/              # App entry point
│       ├── Core/             # GestureEngine, TrackpadTouchView, HapticEngine
│       ├── Networking/       # iOSSessionManager (MC browser)
│       ├── ViewModels/       # TrackpadViewModel
│       ├── Views/            # Content, StatusBar, Keyboard, Onboarding, Settings
│       ├── Assets.xcassets/
│       └── Info.plist
│
├── docs/                     # Documentation
│   ├── architecture.md
│   ├── protocol.md
│   └── privacy-policy.md
│
└── README.md
```

---

## Build & Run Instructions

### Prerequisites
1. Install Xcode 15+ from the Mac App Store
2. Ensure both devices are on the same Wi-Fi network
3. Have an Apple Developer account (free is sufficient for device testing)

### Mac App

```bash
# Open in Xcode
open PocketPadMac/PocketPadMac.xcodeproj

# Or build from command line
xcodebuild -project PocketPadMac/PocketPadMac.xcodeproj \
  -scheme PocketPadMac \
  -configuration Debug \
  build
```

**In Xcode:**
1. Open `PocketPadMac/PocketPadMac.xcodeproj`
2. Select your development team in Signing & Capabilities
3. Click **Run** (⌘R)
4. On first launch, complete the onboarding and **grant Accessibility permission**
5. The app appears in your menu bar with a hand icon

### iPhone App

```bash
# Open in Xcode
open PocketPadIOS/PocketPadIOS.xcodeproj

# Or build from command line
xcodebuild -project PocketPadIOS/PocketPadIOS.xcodeproj \
  -scheme PocketPadIOS \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  build
```

**In Xcode:**
1. Open `PocketPadIOS/PocketPadIOS.xcodeproj`
2. Select your development team
3. Connect your iPhone via USB or select it as a wireless destination  
4. Click **Run** (⌘R)
5. On first launch, complete onboarding and allow Local Network access when prompted

---

## Signing & Entitlements

### Mac App
| Setting | Value |
|---------|-------|
| Sandbox | **Disabled** (required for CGEvent injection) |
| Network Client | Enabled |
| Network Server | Enabled |
| Hardened Runtime | Enabled (Release) / Disabled (Debug) |

> **Note:** The Mac app **must** run outside the sandbox to inject input events via CGEvent. This means it cannot be distributed via the Mac App Store without significant changes. For distribution, use Developer ID signing or direct distribution.

### iPhone App  
| Setting | Value |
|---------|-------|
| Bundle ID | `com.pocketpad.ios` |
| Target Device | iPhone only |
| Local Network | Required (Bonjour `_pocketpad-ctrl._tcp`) |

---

## Permissions

### Mac
| Permission | Why | How to Grant |
|-----------|-----|-------------|
| **Accessibility** | Move cursor, click, scroll, type | System Settings → Privacy & Security → Accessibility → Enable PocketPad |
| **Local Network** | Discover and connect to iPhone | Auto-prompted on first connection |

### iPhone
| Permission | Why | How to Grant |
|-----------|-----|-------------|
| **Local Network** | Discover and connect to Mac | Auto-prompted on first launch |

---

## macOS Security Notes

PocketPad uses **CGEvent-based input injection** to control the Mac. This is the standard, documented Apple API for programmatic input. Key points:

- **Accessibility permission** is mandatory. Without it, all CGEvent posts are silently ignored.
- The Mac app runs **outside the sandbox** because sandboxed apps cannot post CGEvents.
- All input injection code is in `InputInjector.swift` — a clean abstraction layer.
- No private APIs are used.
- The app includes a **permission onboarding flow** that guides users through granting access.

---

## Keyboard Support

### Supported
- ✅ All languages available on the iPhone keyboard (Hebrew, English, Arabic, Chinese, etc.)
- ✅ Emoji
- ✅ Numbers and symbols
- ✅ Special keys: Enter, Delete, Tab, Escape, Arrows, Home/End, Page Up/Down
- ✅ Function keys F1-F12
- ✅ Modifier keys: Command, Option, Control, Shift
- ✅ Common shortcuts: Cmd-C/V/X/Z/A/S/W/Q/Tab/Space

### Limitations
- Text is sent character-by-character using `CGEvent.keyboardSetUnicodeString`. This works for all Unicode text but does not perfectly replicate every macOS IME behavior (e.g., Romaji-to-Kana conversion with live preview).
- Keyboard shortcuts send virtual key codes; they work for standard US keyboard mappings. For non-Latin keyboard layouts, shortcuts use the character-based fallback.
- No support for Touch Bar or custom Input Methods that require deep system integration.

---

## Test Scenarios

### Connection
- [ ] Mac app starts, appears in menu bar
- [ ] iPhone discovers Mac within 5 seconds on same network
- [ ] Tap Mac name → connects successfully
- [ ] Connection state shows "Connected" on both devices
- [ ] Disconnect from iPhone → Mac shows "Disconnected"
- [ ] Kill Mac app → iPhone shows "Reconnecting" → reconnects when Mac restarts

### Trackpad
- [ ] Single finger swipe → cursor moves smoothly
- [ ] Single tap → left click
- [ ] Two-finger tap → right click (context menu)
- [ ] Two-finger vertical swipe → scroll
- [ ] Double-tap → double-click (select word in text editor)
- [ ] Long press + drag → click-and-drag
- [ ] Fast movement → cursor covers large distance (acceleration)
- [ ] Slow precise movement → fine cursor control

### Keyboard
- [ ] Type English text → appears on Mac
- [ ] Type Hebrew text → appears on Mac
- [ ] Type emoji → appears on Mac
- [ ] Tap Enter → new line / confirm
- [ ] Tap Delete → backspace
- [ ] Arrow keys → cursor navigation
- [ ] Cmd-C then Cmd-V → copy-paste works
- [ ] Cmd-Tab → app switcher

### Orientation
- [ ] Rotate to landscape → layout splits trackpad + controls
- [ ] Tap keyboard button → keyboard appears
- [ ] Rotate back to portrait → full trackpad view

### Settings
- [ ] Change sensitivity → cursor speed changes
- [ ] Toggle haptic feedback → feedback stops/starts
- [ ] Toggle tap-to-click → taps stop/start registering as clicks

---

## Known Limitations

1. **Mac App Store**: Cannot distribute via Mac App Store (requires sandbox disabled for CGEvent)
2. **Background Mode (iOS)**: iOS may suspend the app after ~30s in background. Keep PocketPad in the foreground for uninterrupted use.
3. **IME Parity**: Not all macOS input methods are fully replicated. Standard Unicode character insertion is used as a reliable fallback.
4. **Pinch-to-Zoom**: Implemented as Ctrl+scroll (macOS standard zoom). True multitouch pinch requires private APIs.
5. **Multi-Mac**: v1 supports connecting to one Mac at a time.

---

## Future Roadmap

- [ ] iPad support with extended trackpad area
- [ ] Apple Pencil support for precise cursor control
- [ ] Custom gesture mapping (three-finger swipe → Mission Control, etc.)
- [ ] Clipboard sync between devices
- [ ] Screen mirroring preview
- [ ] Widget for quick connection
- [ ] macOS Input Method bridging for CJK languages
- [ ] Multi-Mac switching
- [ ] App Store distribution (with alternative input injection approach)

---

## Assumptions Made

1. **MultipeerConnectivity** is sufficient for v1 latency targets (typically <10ms on local Wi-Fi).
2. Both devices are on the same local network or within Bluetooth range.
3. The user can grant Accessibility permission on macOS (admin password may be required).
4. Development signing is used (no enterprise or App Store signing configured).
5. Portrait and landscape are the primary orientations; upside-down portrait is not supported.
6. The user's Mac runs macOS 13+ (Ventura or later).
7. Hebrew input works via iOS's native keyboard → sent as Unicode characters → injected via CGEvent. This is the most reliable cross-language approach.

---

## Architecture

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation.

## Protocol

See [docs/protocol.md](docs/protocol.md) for the wire protocol specification.

## Privacy

See [docs/privacy-policy.md](docs/privacy-policy.md) for the privacy policy.

---

## License

MIT License. See LICENSE file for details.
