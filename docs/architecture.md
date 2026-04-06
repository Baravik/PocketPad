# PocketPad — Architecture

## High-Level Design

```
┌─────────────────────┐         MultipeerConnectivity         ┌─────────────────────┐
│     iPhone App      │ ◄──── (Encrypted, Local Network) ───► │      Mac App        │
│                     │                                        │                     │
│  ┌───────────────┐  │                                        │  ┌───────────────┐  │
│  │ GestureEngine │  │    Cursor/Scroll/Click/Keyboard msgs   │  │ MacSessionMgr │  │
│  │  (touches →   │──┼──────────────────────────────────────►│  │ (receives &   │  │
│  │   gestures)   │  │                                        │  │  dispatches)  │  │
│  └───────────────┘  │                                        │  └───────┬───────┘  │
│          │          │                                        │          │          │
│  ┌───────▼───────┐  │                                        │  ┌───────▼───────┐  │
│  │ ViewModel     │  │           Settings sync                │  │ PointerProc.  │  │
│  │ (coordinates) │  │ ◄────────────────────────────────────  │  │ (acceleration │  │
│  └───────┬───────┘  │                                        │  │  smoothing)   │  │
│          │          │                                        │  └───────┬───────┘  │
│  ┌───────▼───────┐  │                                        │  ┌───────▼───────┐  │
│  │ SwiftUI Views │  │                                        │  │ InputInjector │  │
│  │ (trackpad,    │  │                                        │  │ (CGEvent API) │  │
│  │  keyboard)    │  │                                        │  └───────────────┘  │
│  └───────────────┘  │                                        │                     │
└─────────────────────┘                                        └─────────────────────┘
```

## Layer Architecture

### iPhone App (MVVM)

| Layer | Component | Responsibility |
|-------|-----------|---------------|
| **View** | `ContentView`, `StatusBarView`, `KeyboardInputView` | UI rendering, orientation handling |
| **ViewModel** | `TrackpadViewModel` | Coordinates gestures → network messages, state management |
| **Core** | `GestureEngine` | Raw touches → gesture recognition |
| | `TrackpadTouchView` | UIKit multi-touch capture (UIViewRepresentable) |
| | `HapticEngine` | Haptic feedback |
| **Network** | `iOSSessionManager` | MultipeerConnectivity browser, message sending |

### Mac App

| Layer | Component | Responsibility |
|-------|-----------|---------------|
| **View** | `MenuBarView`, `MainWindowView`, `MacSettingsView`, `OnboardingView` | UI |
| **Network** | `MacSessionManager` | MultipeerConnectivity advertiser, message routing |
| **Processing** | `PointerProcessor` | Acceleration, smoothing, jitter rejection, inertia |
| **Injection** | `InputInjector` | CGEvent-based cursor, click, scroll, keyboard injection |
| **Permissions** | `PermissionManager` | Accessibility permission checking and guidance |
| **Settings** | `MacSettingsManager` | UserDefaults persistence, Launch at Login |

### Shared

| Component | Responsibility |
|-----------|---------------|
| `PocketPadProtocol` | Message types, wire format (JSON envelope), encoding/decoding |
| `ConnectionState` | Shared connection state model |

## Data Flow (Cursor Movement)

1. User touches iPhone screen
2. `TrackpadTouchView` captures raw `UITouch` events (with coalesced touches)
3. `GestureEngine` processes touches → emits `.move(dx, dy)` gesture
4. `TrackpadViewModel.handleGesture()` calls `iOSSessionManager.sendCursorMove()`
5. `PocketPadCoder.cursorMove()` encodes as JSON envelope
6. `MCSession.send()` transmits via unreliable mode (lowest latency)
7. `MacSessionManager` receives data and decodes envelope
8. `PointerProcessor.processCursorDelta()` applies acceleration, smoothing, jitter filter
9. `InputInjector.moveCursor()` posts `CGEvent.mouseMoved` to system

## Key Design Decisions

1. **MultipeerConnectivity** chosen over raw Network.framework for automatic peer discovery + Bluetooth fallback
2. **Cursor moves use unreliable transport** for minimum latency; clicks/keyboard use reliable
3. **UIKit `TrackpadTouchView`** instead of SwiftUI gestures for access to coalesced touches and raw touch events
4. **Sandbox disabled** on Mac because CGEvent injection requires it
5. **JSON encoding** for protocol messages — simple, debuggable, fast enough for this use case
6. **Character-based keyboard injection** (`keyboardSetUnicodeString`) for full multilingual support instead of key-code-based typing
