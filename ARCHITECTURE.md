# Architecture - WakeTFapp

## Component diagram

```
+------------------+     +-------------------+     +---------------------+
|   SwiftUI Views  |---->| AlarmCoordinator  |---->| ExtendedRuntime     |
|                  |     |   (@MainActor)    |     |   Controller        |
| AlarmSetupView   |     |                   |     | (WKExtendedRuntime  |
| ArmedView        |     | - state machine   |     |  SessionDelegate)   |
| MonitoringView   |     | - arm/disarm      |     +---------------------+
| AlertingView     |     | - evaluation loop |
| LastResultView   |     +--------+----------+
+------------------+              |
                                  |
                    +-------------+-------------+
                    |             |             |
          +---------+    +-------+---+    +----+------+
          | Motion  |    | HeartRate |    | Wake      |
          | Monitor |    | Monitor   |    | Scorer    |
          | (CMM)   |    | (HK)     |    | (pure)    |
          +---------+    +-----------+    +-----------+
                    |             |
                    +------+------+
                           |
                    +------+------+
                    | WakeFeature |
                    | Aggregator  |
                    | (actor)     |
                    +-------------+
                           |
                    +------+------+
                    | AlarmStore  |
                    | (UserDefs)  |
                    +-------------+
```

## Runtime session lifecycle

```
User taps Arm
    |
    v
[scheduling] --> validate window, request permissions
    |
    v
[armed] --> WKExtendedRuntimeSession.start(at: earliestDate)
    |              session is scheduled for future start
    v
System launches app at earliestDate
    |
    v
handle(_: WKExtendedRuntimeSession) in WKApplicationDelegate
    |
    v
[monitoring] --> extendedRuntimeSessionDidStart
    |              - start motion collection
    |              - start heart rate query
    |              - schedule deadline timer
    |              - evaluation loop every 15s
    |
    +---> score above threshold x2 --> [alerting]
    |                                      |
    +---> deadline reached -----------> [alerting]
    |                                      |
    +---> sessionWillExpire -----------> [alerting]
    |                                      |
    |                              notifyUser(hapticType:)
    |                                      |
    +---> user taps Stop -------> [completed]
    |
    +---> user taps Disarm -----> [disarmed]
    |
    +---> system invalidates ----> [failed]
```

## Sensor pipeline

1. **CMMotionManager** collects device motion at ~10 Hz on a dedicated OperationQueue
2. Samples are kept in a rolling 15-second window
3. Every 15 seconds, `MotionMonitor.currentFeatures()` computes:
   - RMS acceleration, variance, peak magnitude
   - Movement burst count, time since last burst
   - Orientation change magnitude
4. **HKAnchoredObjectQuery** receives heart-rate samples as they are recorded
   - Rolling buffer of last 20 samples
   - Freshness checked against 5-minute limit
   - Baseline, rise, and trend computed
5. **WakeFeatureAggregator** (actor) combines both into `AggregatedFeatures`
6. History is maintained for baseline updates

## Wake-score calculation

The `WakeScorer` is a pure value type with no shared mutable state.

### Motion score (0.0 - 1.0)
- 35% RMS deviation from baseline (normalized by MAD)
- 25% movement burst count (normalized to 5)
- 25% peak magnitude (normalized to burst threshold)
- 15% orientation change magnitude

### Heart rate score (0.0 - 1.0)
- 60% rise from baseline (normalized to 15 BPM)
- 40% short-term trend (rising/stable/falling)

### Combined score
- Motion + HR available: 75% motion, 25% heart rate
- Motion only: 100% motion
- No motion: no trigger (wait for deadline)

### Trigger conditions
- Combined score >= sensitivity threshold for 2 consecutive windows
- OR peak magnitude >= 2.0g (strong burst, bypasses warmup)

### Warmup period
- First ~150 seconds: no trigger unless strong burst
- Allows baselines to stabilize

### Sensitivity thresholds
- Low: 0.80 (harder to trigger early)
- Normal: 0.68
- High: 0.56 (easier to trigger early)

## Persistence model

- **AlarmPlan**: Codable struct stored in UserDefaults
- Single active plan at a time
- **AlarmOutcome**: Last result stored separately
- No raw sensor data persisted
- Only aggregate diagnostics, trigger reason, and timing

## Concurrency boundaries

- **@MainActor**: AlarmCoordinator, all SwiftUI views
- **OperationQueue**: Motion sample collection (off main thread)
- **Actor**: WakeFeatureAggregator (isolated state)
- **Value types**: WakeScorer, AlarmScheduleCalculator (no shared state)
- **@unchecked Sendable**: MotionMonitor, HeartRateMonitor, ExtendedRuntimeController (internally locked)

Strict concurrency checking is enabled (`SWIFT_STRICT_CONCURRENCY = complete`).

## Privacy decisions

- No network access whatsoever
- No account system
- No advertising or analytics frameworks
- No raw sensor data persisted
- Heart rate is read-only and optional
- All data remains on the Apple Watch
- No third-party dependencies
- Minimal release logging (no health values)

## Failure handling

- **Session invalidation**: Stop all sensors, record outcome, clean up state
- **HealthKit unavailable**: Fall back to motion-only mode
- **Motion unavailable**: Wait for deadline (no early trigger)
- **Session expiring**: Immediate trigger via `extendedRuntimeSessionWillExpire`
- **App relaunch**: Delegate receives resumed session, reattaches immediately
- **Re-arm after failure**: Old session must be fully invalidated before creating new one
