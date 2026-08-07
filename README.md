# WakeTFapp

A smart wake alarm for Apple Watch. No subscriptions, no accounts, no tracking, no network - just a local alarm that tries to wake you at the right moment.

## How it works

You set a wake window (e.g. 9:30 - 10:00). During that window, the app monitors your wrist movement and optionally heart rate. When it detects signs of natural waking, it fires a repeating haptic alarm. If nothing is detected, it fires at your latest time. Simple.

**Privacy-first**: All data stays on your watch. No network requests, no cloud, no analytics. See [PRIVACY.md](PRIVACY.md) for details.

## Features

- Configurable 5-30 minute wake window
- Motion-based wake detection via accelerometer
- Optional heart rate monitoring for improved accuracy
- Three sensitivity levels (Low / Normal / High)
- Repeating haptic alarm via watchOS Smart Alarm API
- Works standalone - no iPhone app required after install
- DEBUG mode for testing with short windows

## Requirements

- Apple Watch Series 6 or later (tested on Series 10)
- watchOS 11.0+
- Xcode 16+ with watchOS SDK
- macOS for building

## Quick start

```bash
git clone git@github.com:acwo/waketfapp.git
cd waketfapp
open WakeTFapp.xcodeproj
```

In Xcode:
1. Select the **WakeTFapp Watch App** target
2. Under **Signing & Capabilities**, select your development team
3. Change the bundle identifier if needed (default: `com.waketfapp.watchapp`)
4. Choose your Apple Watch (or simulator) as the run destination
5. Build & Run

## Build from command line

```bash
# Simulator build
xcodebuild build \
  -project WakeTFapp.xcodeproj \
  -scheme "WakeTFapp Watch App" \
  -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" \
  CODE_SIGNING_ALLOWED=NO

# Run tests
xcodebuild test \
  -project WakeTFapp.xcodeproj \
  -scheme "WakeTFapp Watch App" \
  -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" \
  CODE_SIGNING_ALLOWED=NO
```

Find available watch simulators with:
```bash
xcrun simctl list devices available | grep -i watch
```

## Installing on a physical Apple Watch

1. Pair your Apple Watch with your iPhone
2. Connect iPhone to Mac via USB
3. Enable **Developer Mode** on both iPhone and Apple Watch (Settings > Privacy & Security > Developer Mode)
4. Add your Apple account in Xcode > Settings > Accounts
5. Select the physical Apple Watch as the run destination in Xcode
6. Build & Run
7. Approve HealthKit and Motion permissions on the watch

**Free Personal Team note**: Development profiles expire after 7 days. You'll need to rebuild and reinstall after that. A paid Apple Developer Program membership removes this limitation.

## Usage

1. Open WakeTFapp on your Apple Watch
2. Set earliest and latest wake times (max 30 min apart)
3. Choose sensitivity
4. Tap **Arm**
5. Go to sleep - the session activates at your earliest time
6. When you stir, the haptic fires
7. Tap **Stop** to dismiss

## The 30-minute limit

watchOS limits Smart Alarm extended runtime sessions to 30 minutes. This is a hard platform constraint - there is no workaround. The app validates this and won't let you set a window longer than 30 minutes.

If you want to wake between 9:00 and 10:00, set it to 9:30 - 10:00 (the last 30 minutes of your desired range).

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the component diagram, session lifecycle, sensor pipeline, and concurrency model.

## Project structure

```
WakeTFapp Watch App/
  App/             - App entry point, delegate
  Models/          - AlarmPlan, AlarmStatus, Sensitivity, validation
  Features/        - SwiftUI views (Setup, Armed, Monitoring, Alerting)
  Services/        - AlarmCoordinator, motion, heart rate, scoring
  Support/         - Logging
  Resources/       - Assets, localization

WakeTFappTests/    - Unit tests (schedule, scoring, state machine)
```

## Troubleshooting

**Watch doesn't appear in Xcode** - Enable Developer Mode on both devices, connect iPhone via USB, restart both devices if needed.

**Alarm doesn't fire** - Ensure Wrist Detection is on. The app must be active (foreground) when you tap Arm.

**HealthKit denied** - The app works fine in motion-only mode. Re-enable in Settings > Privacy & Security > Health > WakeTFapp.

## License

MIT
