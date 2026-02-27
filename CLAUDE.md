# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pleaco is a SwiftUI iOS app that controls sex toys (The Handy, Oh., Intiface/Buttplug, LoveSpouse, phone haptics) via real-time waveform patterns and FunScript playback.

- **Language**: Swift 5.9+, **UI**: SwiftUI, **Min Target**: iOS 16.0
- **No external dependencies** — native frameworks only (SwiftUI, Combine, CoreBluetooth, CoreHaptics, AVFoundation, URLSession)
- **No tests, no SwiftLint**

## Build Commands

```bash
# Build for iOS Simulator
xcodebuild -project pleaco.xcodeproj -scheme pleaco -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Build for macOS
xcodebuild -project pleaco.xcodeproj -scheme pleaco -configuration Debug \
  -destination 'platform=macOS' build
```

Open `pleaco.xcodeproj` in Xcode to run on device/simulator.

## Architecture

### Data & Control Flow

```
ContentView (3-tab via CustomTopBar)
  ├── HomeView            ← pattern grid + PlayerCard (always visible footer)
  ├── AudioView           ← audio library + PlayerCard (shared footer)
  └── SettingsView        ← device CRUD + stroke range + OSSM config

DeviceManager.shared      ← central orchestrator (ObservableObject singleton)
  ├── HandyManager.shared     (The Handy / Oh. — HTTPS REST API)
  ├── ButtplugManager.shared  (Intiface — WebSocket, Buttplug.io protocol)
  ├── LoveSpouseManager.shared (LoveSpouse — BLE Peripheral advertising)
  ├── OSSMManager.shared      (OSSM — BLE Central, custom GATT protocol)
  └── HapticManager.shared    (Phone — CoreHaptics)

AudioManager.shared       ← AVAudioEngine playback + RMS amplitude → DeviceManager.setLevel()

PatternEngine             ← static: wave math, FunScript interpolation, waveform preview curves
ThemeManager              ← Color/LinearGradient extensions, ButtonStyles
FunScriptModels           ← FunScriptData, NamedFunScript, PatternGroup
```

### DeviceManager

The single source of truth. All views observe `DeviceManager.shared`. Key responsibilities:
- Manages the `devices: [SavedDevice]` list and the single `activeDevice`
- The internal (Phone) device is a stable singleton `internalDevice` kept separate from `devices`
- Owns the wave timer that samples patterns at device-appropriate rates (10 Hz for Handy/Oh./OSSM, 5 Hz for LoveSpouse, up to 50 Hz for internal)
- Routes `sendLevel(_:)` to the correct hardware manager
- Persists state to `UserDefaults` (devices, active device, preset, stroke range, custom scripts, OSSM params)

### Pattern Modes (mutually exclusive)

1. **Software Preset** (`selectedPreset: DeviceWavePreset`) — math-generated waveform in `calculateWaveValue(time:)`
2. **FunScript** (`activeFunScript: FunScriptData`) — interpolated from timestamped position actions
3. **LoveSpouse/OSSM Hardware Program** (`selectedLoveSpouseProgram: Int 1–9`) — direct hardware command; software speed updates are suppressed to prevent command collisions
4. **Audio Sync** (`activeAudioTrack: SavedAudioTrack`) — `AudioManager` computes RMS amplitude from AVAudioEngine tap and calls `DeviceManager.setLevel()` in real-time; a 230 ms `AVAudioUnitDelay` node offsets Bluetooth latency

### Device Communication

| Device | Protocol | Key |
|--------|----------|-----|
| The Handy / Oh. | HTTPS REST (`handyfeeling.com/api/handy/v2`) | `X-Connection-Key` header, 5 s timeout |
| Intiface | WebSocket (`ws://host:12345`), Buttplug.io JSON | `serverAddress` |
| LoveSpouse | BLE Peripheral (iPhone acts as broadcaster) | reverse-engineered 16-bit service UUIDs |
| OSSM | BLE Central (iPhone scans & connects) | custom GATT service `522b443a-…-0001-…`; text commands like `go:strokeEngine`, `set:speed:80` |
| Phone | CoreHaptics | `HapticManager` |

### Theming

All colors are `static` properties on `Color` and `LinearGradient` in `ThemeManager.swift`. The accent color comes from the `AppTint` asset (`Color.appAccent`). Custom button styles: `ScaleButtonStyle`, `GlowButtonStyle`.

## Key Conventions

- **Singletons**: `static let shared = X()` with `private init()`. Views use `@ObservedObject var x = X.shared`.
- **UI updates from background**: always dispatch to `DispatchQueue.main.async`.
- **Logging**: `NSLog("🔔 ManagerName: message")` for significant events; `print` for verbose debug only.
- **Persistence**: `UserDefaults` for scalars; `JSONEncoder/Decoder` for `[SavedDevice]` and `[NamedFunScript]`.
- **FunScript actions** are sorted ascending by `at` (ms) on import.
- Adding a new `DeviceWavePreset` case requires updates in: `DeviceManager.timerInterval(for:)`, `DeviceManager.calculateWaveValue(time:)`, and `PatternEngine.generateValue(_:time:)` (both must stay in sync — `calculateWaveValue` drives the live timer, `generateValue` drives waveform preview rendering).
- **OSSM Stroker Mode**: when `ossmStrokerMode` is true, `OSSMManager` automatically derives `stroke` from `depth` and vice versa using the OSSM-Possum formula. The OSSM state characteristic is intentionally NOT subscribed to (firmware bug causes crash on notification flood).
- **Audio files** are stored in the app's `Documents/AudioTracks/` directory; supported formats: mp3, wav, m4a.
