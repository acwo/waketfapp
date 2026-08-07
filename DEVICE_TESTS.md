# Device Tests - WakeTFapp

## Environment

- **Mac**: Apple Silicon M1, macOS 26.5.2
- **Xcode**: 26.5 (Build 17F42)
- **watchOS SDK**: 26.5
- **Simulator tested**: Apple Watch Series 11 (46mm) - watchOS 26.5
- **Physical device**: Apple Watch Series 10 (not connected at build time)
- **Build result**: 0 errors, 0 warnings
- **Test result**: 27/27 tests pass (AlarmScheduleCalculator: 10, WakeScorer: 8, StateMachine: 9)
- **Simulator launch**: App installs and launches successfully

## Test matrix

| # | Test case | Expected result | Actual result | Status |
|---|-----------|----------------|---------------|--------|
| 1 | Watch worn on wrist | App launches and functions normally | - | Not tested |
| 2 | Wrist Detection enabled | Session activates at scheduled time | - | Not tested |
| 3 | Sleep Focus enabled | Alarm fires through Focus mode | - | Not tested |
| 4 | Silent Mode enabled | Haptic alarm still fires (haptic, not audio) | - | Not tested |
| 5 | iPhone nearby | No effect on watch-only app | - | Not tested |
| 6 | iPhone not in use | No effect on watch-only app | - | Not tested |
| 7 | HealthKit permission allowed | Heart rate monitoring active during window | - | Not tested |
| 8 | HealthKit permission denied | App falls back to motion-only mode | - | Not tested |
| 9 | Heart rate samples available | HR contributes to wake score | - | Not tested |
| 10 | No fresh HR samples | App uses motion-only scoring | - | Not tested |
| 11 | App visible at session start | Monitoring screen appears | - | Not tested |
| 12 | App not visible at session start | App relaunches via delegate | - | Not tested |
| 13 | App removed from recent apps | Session still fires via system relaunch | - | Not tested |
| 14 | Early trigger (movement) | Alarm fires before latest time | - | Not tested |
| 15 | Deadline fallback (no movement) | Alarm fires at latest time | - | Not tested |
| 16 | Manual disarm | Alarm cancelled, outcome recorded | - | Not tested |
| 17 | Re-arm after disarm | New session schedules successfully | - | Not tested |
| 18 | Watch restarted after scheduling | Session may be lost (document behavior) | - | Not tested |
| 19 | Low battery condition | System may terminate session early | - | Not tested |
| 20 | Stop button during alerting | Haptic stops, session invalidated | - | Not tested |
| 21 | Window validation (>30 min) | Error message shown, Arm disabled | - | Not tested |
| 22 | Window validation (<5 min) | Error message shown, Arm disabled | - | Not tested |
| 23 | Debug short window (2 min) | Works in DEBUG mode only | - | Not tested |

## Notes

- All tests are marked "Not tested" because Xcode was not available during initial development
- Physical device testing requires Xcode to be installed and the project built
- Once Xcode is available, run the DEBUG short-window test first to verify basic functionality
- Simulator testing can validate UI flows but not actual sensor data or extended runtime behavior

## Known untestable scenarios (simulator)

- Actual wrist motion detection
- Real heart rate sample delivery during sleep
- True extended runtime session behavior (relaunch, expiry)
- Haptic intensity and wake effectiveness
- Battery impact during overnight scheduled session
