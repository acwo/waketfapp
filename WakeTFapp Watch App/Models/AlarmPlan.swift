import Foundation

struct AlarmPlan: Codable, Equatable, Sendable {
	let id: UUID
	var earliestDate: Date
	var latestDate: Date
	var sensitivity: Sensitivity
	var useHeartRate: Bool
	var armedAt: Date
	var status: AlarmStatus
	var triggeredAt: Date?
	var triggerReason: AlarmTriggerReason?

	var windowDuration: TimeInterval {
		latestDate.timeIntervalSince(earliestDate)
	}

	var windowDurationMinutes: Int {
		Int(windowDuration / 60)
	}

	static func create(
		earliest: Date,
		latest: Date,
		sensitivity: Sensitivity,
		useHeartRate: Bool
	) -> AlarmPlan {
		AlarmPlan(
			id: UUID(),
			earliestDate: earliest,
			latestDate: latest,
			sensitivity: sensitivity,
			useHeartRate: useHeartRate,
			armedAt: Date(),
			status: .scheduling,
			triggeredAt: nil,
			triggerReason: nil
		)
	}
}
