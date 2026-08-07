import Foundation

struct AlarmOutcome: Codable, Sendable {
	let id: UUID
	let armedAt: Date
	let earliestDate: Date
	let latestDate: Date
	let sensitivity: Sensitivity
	let usedHeartRate: Bool
	let result: AlarmResult
	let completedAt: Date

	enum AlarmResult: String, Codable, Sendable {
		case triggeredEarly
		case triggeredAtDeadline
		case manuallyDisarmed
		case sessionFailed
	}

	var triggerReason: AlarmTriggerReason?
	var triggeredAt: Date?
	var failureDescription: String?
}

extension AlarmOutcome {
	var localizedResultDescription: String {
		switch result {
		case .triggeredEarly:
			return triggerReason?.localizedDescription
				?? String(localized: "outcome_early", defaultValue: "Woke you at a gentle moment")
		case .triggeredAtDeadline:
			return String(localized: "outcome_deadline", defaultValue: "Woke you at latest time")
		case .manuallyDisarmed:
			return String(localized: "outcome_disarmed", defaultValue: "Alarm was disarmed")
		case .sessionFailed:
			return String(localized: "outcome_failed", defaultValue: "Alarm session ended unexpectedly")
		}
	}
}
