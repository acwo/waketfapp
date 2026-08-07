import Foundation

enum AlarmValidationError: Error, Sendable {
	case windowTooShort(minutes: Int)
	case windowTooLong(minutes: Int)
	case earliestInPast
	case latestBeforeEarliest
	case alarmAlreadyScheduled

	var localizedDescription: String {
		switch self {
		case .windowTooShort(let minutes):
			return String(
				localized: "validation_too_short",
				defaultValue: "Wake window must be at least 5 minutes. Currently \(minutes) minutes."
			)
		case .windowTooLong(let minutes):
			return String(
				localized: "validation_too_long",
				defaultValue: "watchOS supports a maximum 30-minute smart wake window. Currently \(minutes) min. Choose a later earliest time or an earlier latest time. For example, use the last 30 minutes of your desired range."
			)
		case .earliestInPast:
			return String(
				localized: "validation_past",
				defaultValue: "Earliest time must be in the future."
			)
		case .latestBeforeEarliest:
			return String(
				localized: "validation_order",
				defaultValue: "Latest time must be after earliest time."
			)
		case .alarmAlreadyScheduled:
			return String(
				localized: "validation_exists",
				defaultValue: "An alarm is already scheduled. Disarm it first."
			)
		}
	}
}

struct AlarmValidation: Sendable {
	static let minimumWindowMinutes = 5
	static let maximumWindowMinutes = 30
	static let minimumFutureSeconds: TimeInterval = 60

	#if DEBUG
	nonisolated(unsafe) static var debugMinimumWindowMinutes = 1
	nonisolated(unsafe) static var debugMinimumFutureSeconds: TimeInterval = 10
	#endif

	static func validate(
		earliest: Date,
		latest: Date,
		now: Date = Date(),
		hasExistingAlarm: Bool = false,
		isDebugMode: Bool = false
	) -> AlarmValidationError? {
		if hasExistingAlarm {
			return .alarmAlreadyScheduled
		}

		let minFuture: TimeInterval
		let minWindow: Int

		#if DEBUG
		if isDebugMode {
			minFuture = debugMinimumFutureSeconds
			minWindow = debugMinimumWindowMinutes
		} else {
			minFuture = minimumFutureSeconds
			minWindow = minimumWindowMinutes
		}
		#else
		minFuture = minimumFutureSeconds
		minWindow = minimumWindowMinutes
		#endif

		if earliest.timeIntervalSince(now) < minFuture {
			return .earliestInPast
		}

		if latest <= earliest {
			return .latestBeforeEarliest
		}

		let durationMinutes = Int(latest.timeIntervalSince(earliest) / 60)

		if durationMinutes < minWindow {
			return .windowTooShort(minutes: durationMinutes)
		}

		if durationMinutes > maximumWindowMinutes {
			return .windowTooLong(minutes: durationMinutes)
		}

		return nil
	}
}
