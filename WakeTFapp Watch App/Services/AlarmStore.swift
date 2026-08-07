import Foundation

protocol AlarmStoreProtocol: Sendable {
	func loadPlan() -> AlarmPlan?
	func savePlan(_ plan: AlarmPlan)
	func clearPlan()
	func loadLastOutcome() -> AlarmOutcome?
	func saveOutcome(_ outcome: AlarmOutcome)
}

final class AlarmStore: AlarmStoreProtocol, @unchecked Sendable {
	private let defaults: UserDefaults
	private let planKey = "com.waketfapp.activePlan"
	private let outcomeKey = "com.waketfapp.lastOutcome"
	private let encoder = JSONEncoder()
	private let decoder = JSONDecoder()

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	func loadPlan() -> AlarmPlan? {
		guard let data = defaults.data(forKey: planKey) else { return nil }
		return try? decoder.decode(AlarmPlan.self, from: data)
	}

	func savePlan(_ plan: AlarmPlan) {
		guard let data = try? encoder.encode(plan) else { return }
		defaults.set(data, forKey: planKey)
	}

	func clearPlan() {
		defaults.removeObject(forKey: planKey)
	}

	func loadLastOutcome() -> AlarmOutcome? {
		guard let data = defaults.data(forKey: outcomeKey) else { return nil }
		return try? decoder.decode(AlarmOutcome.self, from: data)
	}

	func saveOutcome(_ outcome: AlarmOutcome) {
		guard let data = try? encoder.encode(outcome) else { return }
		defaults.set(data, forKey: outcomeKey)
	}
}
