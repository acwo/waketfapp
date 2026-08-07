# Privacy - WakeTFapp

## Summary

WakeTFapp is a fully local, privacy-first Apple Watch alarm. No data ever leaves your device.

## No network access

The app makes zero network requests. It has no networking capabilities configured, no URL sessions, and no remote endpoints. It cannot communicate with any server.

## No account

There is no sign-up, login, or account of any kind. The app works entirely standalone.

## No advertising

The app contains no advertising frameworks, no ad identifiers, and no advertising of any kind.

## No analytics

The app contains no analytics SDKs, no event tracking, no usage telemetry, and no crash reporting services. It does not phone home.

## No raw sensor persistence

- Accelerometer samples are held in memory for a rolling 15-second window only
- Heart rate samples are held in memory (last 20 values) only
- When monitoring stops, all sensor buffers are cleared
- Only the alarm outcome (trigger time, trigger reason, settings used) is persisted

## Heart rate access

- Read-only: the app never writes health data
- Optional: the app functions fully without heart rate authorization
- Limited scope: only the heart rate quantity type is requested
- No sleep analysis, no workouts, no active energy, no other health types
- Fresh samples older than 5 minutes are discarded as stale

## Data stays on device

All persisted data (alarm configuration, last outcome) is stored in the watch's local UserDefaults. There is no iCloud sync, no CloudKit, no companion app data transfer for the MVP.

## No third-party dependencies

The app uses only Apple-provided frameworks:
- SwiftUI
- WatchKit
- CoreMotion
- HealthKit
- Foundation
- os (for structured logging)

## Logging

- Debug builds may log diagnostic values for development purposes
- Release builds use minimal structured logging via os.Logger
- No health values (heart rate, acceleration magnitudes) are logged in release builds
