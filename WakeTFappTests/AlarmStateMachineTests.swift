import XCTest
@testable import WakeTFapp_Watch_App

final class FakeAlarmStore: AlarmStoreProtocol, @unchecked Sendable {
	var savedPlan: AlarmPlan?
	var savedOutcome: AlarmOutcome?
	var cleared: Bool = false

	func loadPlan() -> AlarmPlan? { savedPlan }
	func savePlan(_ plan: AlarmPlan) { savedPlan = plan }
	func clearPlan() { cleared = true; savedPlan = nil }
	func loadLastOutcome() -> AlarmOutcome? { savedOutcome }
	func saveOutcome(_ outcome: AlarmOutcome) { savedOutcome = outcome }
}

final class FakeMotionMonitor: MotionMonitorProtocol, @unchecked Sendable {
	var isAvailable: Bool = true
	var isMonitoring: Bool = false
	var fakeFeatures: MotionFeatures = .empty

	func startMonitoring() async throws {
		isMonitoring = true
	}

	func stopMonitoring() {
		isMonitoring = false
	}

	func currentFeatures() -> MotionFeatures {
		fakeFeatures
	}
}

final class FakeHeartRateMonitor: HeartRateMonitorProtocol, @unchecked Sendable {
	var isAvailable: Bool = true
	var isAuthorized: Bool = true
	var isMonitoring: Bool = false
	var fakeFeatures: HeartRateFeatures = .unavailable
	var authorizationGranted: Bool = true

	func requestAuthorization() async -> Bool {
		authorizationGranted
	}

	func startMonitoring() async {
		isMonitoring = true
	}

	func stopMonitoring() {
		isMonitoring = false
	}

	func currentFeatures() -> HeartRateFeatures {
		fakeFeatures
	}
}

final class AlarmStateMachineTests: XCTestCase {

	func testAlarmPlanTransitions() {
		var plan = AlarmPlan.create(
			earliest: Date().addingTimeInterval(300),
			latest: Date().addingTimeInterval(1200),
			sensitivity: .normal,
			useHeartRate: true
		)

		XCTAssertEqual(plan.status, .scheduling)

		plan.status = .armed
		XCTAssertEqual(plan.status, .armed)

		plan.status = .monitoring
		XCTAssertEqual(plan.status, .monitoring)

		plan.status = .alerting
		plan.triggeredAt = Date()
		plan.triggerReason = .motionDetected
		XCTAssertEqual(plan.status, .alerting)
		XCTAssertNotNil(plan.triggeredAt)

		plan.status = .completed
		XCTAssertEqual(plan.status, .completed)
	}

	func testDisarmTransition() {
		var plan = AlarmPlan.create(
			earliest: Date().addingTimeInterval(300),
			latest: Date().addingTimeInterval(1200),
			sensitivity: .normal,
			useHeartRate: false
		)

		plan.status = .armed
		plan.status = .disarmed
		XCTAssertEqual(plan.status, .disarmed)
	}

	func testFailedState() {
		var plan = AlarmPlan.create(
			earliest: Date().addingTimeInterval(300),
			latest: Date().addingTimeInterval(1200),
			sensitivity: .high,
			useHeartRate: true
		)

		plan.status = .armed
		plan.status = .failed
		XCTAssertEqual(plan.status, .failed)
	}

	func testPersistenceRoundTrip() {
		let store = FakeAlarmStore()
		let plan = AlarmPlan.create(
			earliest: Date().addingTimeInterval(300),
			latest: Date().addingTimeInterval(1200),
			sensitivity: .low,
			useHeartRate: true
		)

		store.savePlan(plan)
		let loaded = store.loadPlan()
		XCTAssertEqual(loaded, plan)
	}

	func testClearPlan() {
		let store = FakeAlarmStore()
		let plan = AlarmPlan.create(
			earliest: Date().addingTimeInterval(300),
			latest: Date().addingTimeInterval(1200),
			sensitivity: .normal,
			useHeartRate: false
		)

		store.savePlan(plan)
		store.clearPlan()
		XCTAssertNil(store.loadPlan())
		XCTAssertTrue(store.cleared)
	}

	func testOutcomeSave() {
		let store = FakeAlarmStore()
		let outcome = AlarmOutcome(
			id: UUID(),
			armedAt: Date(),
			earliestDate: Date().addingTimeInterval(300),
			latestDate: Date().addingTimeInterval(1200),
			sensitivity: .normal,
			usedHeartRate: true,
			result: .triggeredEarly,
			completedAt: Date(),
			triggerReason: .motionDetected,
			triggeredAt: Date()
		)

		store.saveOutcome(outcome)
		XCTAssertNotNil(store.savedOutcome)
		XCTAssertEqual(store.savedOutcome?.result, .triggeredEarly)
	}

	func testWindowDurationCalculation() {
		let earliest = Date()
		let latest = earliest.addingTimeInterval(1500)
		let plan = AlarmPlan.create(
			earliest: earliest,
			latest: latest,
			sensitivity: .normal,
			useHeartRate: false
		)

		XCTAssertEqual(plan.windowDurationMinutes, 25)
	}

	func testSensitivityThresholds() {
		XCTAssertEqual(Sensitivity.low.threshold, 0.80)
		XCTAssertEqual(Sensitivity.normal.threshold, 0.68)
		XCTAssertEqual(Sensitivity.high.threshold, 0.56)
		XCTAssertGreaterThan(Sensitivity.low.threshold, Sensitivity.normal.threshold)
		XCTAssertGreaterThan(Sensitivity.normal.threshold, Sensitivity.high.threshold)
	}
}
