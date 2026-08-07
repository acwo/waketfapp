import Foundation
import WatchKit
import Combine

@MainActor
final class AlarmCoordinator: ObservableObject {
	@Published private(set) var currentPlan: AlarmPlan?
	@Published private(set) var lastOutcome: AlarmOutcome?
	@Published private(set) var currentScore: WakeScore = .zero
	@Published private(set) var sensorStatus: SensorStatus = .idle
	@Published private(set) var hasRequestedHealthAuth: Bool = false
	@Published var lastError: String?

	enum SensorStatus: Sendable {
		case idle
		case motionOnly
		case motionAndHeartRate
		case noSensors
	}

	private let store: AlarmStoreProtocol
	private let runtimeController: ExtendedRuntimeController
	private let motionMonitor: MotionMonitorProtocol
	private let heartRateMonitor: HeartRateMonitorProtocol
	private let aggregator: WakeFeatureAggregator
	private let scorer: WakeScorer
	private let calculator: AlarmScheduleCalculator

	private var monitoringTask: Task<Void, Never>?
	private var deadlineTask: Task<Void, Never>?
	private var hasTriggered: Bool = false
	private var consecutiveAboveCount: Int = 0
	private var windowIndex: Int = 0
	private var monitoringStartDate: Date?
	private var baseline: WakeScorer.Baseline = .initial
	private var isWaitingForInvalidation: Bool = false
	private var activeSessionID: UUID?

	#if DEBUG
	@Published var isDebugMode: Bool = false
	var debugMotionFeatures: MotionFeatures?
	var debugHeartRateFeatures: HeartRateFeatures?
	#endif

	init(
		store: AlarmStoreProtocol = AlarmStore(),
		runtimeController: ExtendedRuntimeController = ExtendedRuntimeController(),
		motionMonitor: MotionMonitorProtocol = MotionMonitor(),
		heartRateMonitor: HeartRateMonitorProtocol = HeartRateMonitor(),
		aggregator: WakeFeatureAggregator = WakeFeatureAggregator(),
		scorer: WakeScorer = WakeScorer(),
		calculator: AlarmScheduleCalculator = AlarmScheduleCalculator()
	) {
		self.store = store
		self.runtimeController = runtimeController
		self.motionMonitor = motionMonitor
		self.heartRateMonitor = heartRateMonitor
		self.aggregator = aggregator
		self.scorer = scorer
		self.calculator = calculator

		runtimeController.delegate = self
		loadPersistedState()
	}

	func armAlarm(
		earliestHour: Int,
		earliestMinute: Int,
		latestHour: Int,
		latestMinute: Int,
		sensitivity: Sensitivity,
		useHeartRate: Bool
	) async -> Result<AlarmPlan, AlarmValidationError> {
		let isDebug: Bool
		#if DEBUG
		isDebug = isDebugMode
		#else
		isDebug = false
		#endif

		guard !isWaitingForInvalidation else {
			return .failure(.alarmAlreadyScheduled)
		}

		guard let window = calculator.resolveNextOccurrence(
			earliestHour: earliestHour,
			earliestMinute: earliestMinute,
			latestHour: latestHour,
			latestMinute: latestMinute
		) else {
			return .failure(.latestBeforeEarliest)
		}

		if let error = AlarmValidation.validate(
			earliest: window.earliest,
			latest: window.latest,
			hasExistingAlarm: currentPlan != nil,
			isDebugMode: isDebug
		) {
			return .failure(error)
		}

		if useHeartRate {
			let granted = await heartRateMonitor.requestAuthorization()
			if granted {
				hasRequestedHealthAuth = true
				UserDefaults.standard.set(true, forKey: "hasRequestedHealthAuth")
			}
		}

		if runtimeController.session != nil {
			isWaitingForInvalidation = true
			activeSessionID = nil
			runtimeController.invalidateSession()
			try? await Task.sleep(nanoseconds: 1_000_000_000)
			runtimeController.releaseSession()
			isWaitingForInvalidation = false
		}

		var plan = AlarmPlan.create(
			earliest: window.earliest,
			latest: window.latest,
			sensitivity: sensitivity,
			useHeartRate: useHeartRate
		)

		let success = runtimeController.scheduleSession(startDate: window.earliest)
		guard success else {
			return .failure(.alarmAlreadyScheduled)
		}

		plan.status = .armed
		activeSessionID = plan.id
		store.savePlan(plan)
		currentPlan = plan

		return .success(plan)
	}

	func disarm() {
		guard var plan = currentPlan else { return }

		activeSessionID = nil
		lastError = nil
		stopMonitoring()
		runtimeController.invalidateSession()

		let outcome = AlarmOutcome(
			id: plan.id,
			armedAt: plan.armedAt,
			earliestDate: plan.earliestDate,
			latestDate: plan.latestDate,
			sensitivity: plan.sensitivity,
			usedHeartRate: plan.useHeartRate,
			result: .manuallyDisarmed,
			completedAt: Date()
		)

		store.saveOutcome(outcome)
		lastOutcome = outcome

		plan.status = .disarmed
		currentPlan = nil
		store.clearPlan()
		hasTriggered = false
		consecutiveAboveCount = 0
	}

	func stopAlarm() {
		guard let plan = currentPlan, plan.status == .alerting else { return }

		stopMonitoring()
		runtimeController.invalidateSession()

		if lastOutcome == nil || lastOutcome?.id != plan.id {
			let outcome = AlarmOutcome(
				id: plan.id,
				armedAt: plan.armedAt,
				earliestDate: plan.earliestDate,
				latestDate: plan.latestDate,
				sensitivity: plan.sensitivity,
				usedHeartRate: plan.useHeartRate,
				result: plan.triggerReason == .latestTimeFallback || plan.triggerReason == .sessionWillExpireFallback
					? .triggeredAtDeadline : .triggeredEarly,
				completedAt: Date(),
				triggerReason: plan.triggerReason,
				triggeredAt: plan.triggeredAt
			)
			store.saveOutcome(outcome)
			lastOutcome = outcome
		}

		currentPlan = nil
		store.clearPlan()
	}

	func handleResumedSession(_ session: WKExtendedRuntimeSession) {
		runtimeController.attachResumedSession(session)

		if currentPlan == nil {
			if let savedPlan = store.loadPlan() {
				currentPlan = savedPlan
			}
		}
	}

	private func loadPersistedState() {
		currentPlan = store.loadPlan()
		lastOutcome = store.loadLastOutcome()
		hasRequestedHealthAuth = UserDefaults.standard.bool(forKey: "hasRequestedHealthAuth")
	}

	private func startMonitoring() {
		guard var plan = currentPlan else { return }

		plan.status = .monitoring
		currentPlan = plan
		store.savePlan(plan)

		hasTriggered = false
		consecutiveAboveCount = 0
		windowIndex = 0
		monitoringStartDate = Date()
		baseline = .initial

		Task {
			try? await motionMonitor.startMonitoring()
		}

		if plan.useHeartRate && heartRateMonitor.isAvailable {
			Task {
				await heartRateMonitor.startMonitoring()
			}
			sensorStatus = .motionAndHeartRate
		} else {
			sensorStatus = .motionOnly
		}

		startEvaluationLoop()
		scheduleDeadline()
	}

	private func startEvaluationLoop() {
		monitoringTask = Task { [weak self] in
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 15_000_000_000)
				guard !Task.isCancelled else { break }
				await self?.evaluateWakeCondition()
			}
		}
	}

	private func scheduleDeadline() {
		guard let plan = currentPlan else { return }

		let safetyMargin: TimeInterval = 5
		let sessionExpiry = runtimeController.expirationDate ?? plan.latestDate
		let effectiveDeadline = min(plan.latestDate, sessionExpiry.addingTimeInterval(-safetyMargin))

		let delay = effectiveDeadline.timeIntervalSinceNow

		deadlineTask = Task { [weak self] in
			guard delay > 0 else {
				self?.triggerAlarm(reason: .latestTimeFallback)
				return
			}
			try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
			guard !Task.isCancelled else { return }
			self?.triggerAlarm(reason: .latestTimeFallback)
		}
	}

	private func evaluateWakeCondition() async {
		guard !hasTriggered, currentPlan != nil else { return }

		let motionFeatures: MotionFeatures
		let heartRateFeatures: HeartRateFeatures

		#if DEBUG
		if let debugMotion = debugMotionFeatures {
			motionFeatures = debugMotion
		} else {
			motionFeatures = motionMonitor.currentFeatures()
		}
		if let debugHR = debugHeartRateFeatures {
			heartRateFeatures = debugHR
		} else {
			heartRateFeatures = heartRateMonitor.currentFeatures()
		}
		#else
		motionFeatures = motionMonitor.currentFeatures()
		heartRateFeatures = heartRateMonitor.currentFeatures()
		#endif

		let elapsed = monitoringStartDate.map { Date().timeIntervalSince($0) } ?? 0
		windowIndex += 1

		let aggregated = await aggregator.aggregate(
			motion: motionFeatures,
			heartRate: heartRateFeatures,
			elapsedSinceStart: elapsed,
			windowIndex: windowIndex
		)

		let history = await aggregator.recentHistory(count: 8)
		baseline = scorer.updateBaseline(history: history, current: baseline)

		let score = scorer.calculateScore(
			features: aggregated,
			baseline: baseline,
			sensitivity: currentPlan?.sensitivity ?? .normal,
			consecutiveAboveCount: consecutiveAboveCount
		)

		currentScore = score

		if score.isStrongBurst {
			triggerAlarm(reason: .strongMovementBurst)
			return
		}

		if score.isAboveThreshold {
			consecutiveAboveCount += 1
			if consecutiveAboveCount >= 2 {
				let reason: AlarmTriggerReason = aggregated.hasHeartRate ? .motionAndHeartRate : .motionDetected
				triggerAlarm(reason: reason)
			}
		} else {
			consecutiveAboveCount = 0
		}
	}

	private func triggerAlarm(reason: AlarmTriggerReason) {
		guard !hasTriggered else { return }
		hasTriggered = true

		guard var plan = currentPlan else { return }

		plan.status = .alerting
		plan.triggeredAt = Date()
		plan.triggerReason = reason
		currentPlan = plan
		store.savePlan(plan)

		runtimeController.triggerAlarm()

		let outcome = AlarmOutcome(
			id: plan.id,
			armedAt: plan.armedAt,
			earliestDate: plan.earliestDate,
			latestDate: plan.latestDate,
			sensitivity: plan.sensitivity,
			usedHeartRate: plan.useHeartRate,
			result: reason == .latestTimeFallback || reason == .sessionWillExpireFallback || reason == .expirationSafetyFallback
				? .triggeredAtDeadline : .triggeredEarly,
			completedAt: Date(),
			triggerReason: reason,
			triggeredAt: plan.triggeredAt
		)

		store.saveOutcome(outcome)
		lastOutcome = outcome

		deadlineTask?.cancel()
		monitoringTask?.cancel()
	}

	private func stopMonitoring() {
		monitoringTask?.cancel()
		monitoringTask = nil
		deadlineTask?.cancel()
		deadlineTask = nil
		motionMonitor.stopMonitoring()
		heartRateMonitor.stopMonitoring()
		sensorStatus = .idle
		currentScore = .zero
	}
}

extension AlarmCoordinator: ExtendedRuntimeDelegate {
	nonisolated func runtimeSessionDidStart() {
		Task { @MainActor in
			self.startMonitoring()
		}
	}

	nonisolated func runtimeSessionWillExpire() {
		Task { @MainActor in
			if !self.hasTriggered {
				self.triggerAlarm(reason: .sessionWillExpireFallback)
			}
		}
	}

	nonisolated func runtimeSessionDidInvalidate(reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
		Task { @MainActor in
			if self.isWaitingForInvalidation {
				self.runtimeController.releaseSession()
				return
			}

			guard let plan = self.currentPlan, plan.id == self.activeSessionID else {
				self.runtimeController.releaseSession()
				return
			}

			self.stopMonitoring()

			if self.hasTriggered {
				self.currentPlan = nil
				self.store.clearPlan()
			} else if reason != .none && plan.status != .armed {
				let outcome = AlarmOutcome(
					id: plan.id,
					armedAt: plan.armedAt,
					earliestDate: plan.earliestDate,
					latestDate: plan.latestDate,
					sensitivity: plan.sensitivity,
					usedHeartRate: plan.useHeartRate,
					result: .sessionFailed,
					completedAt: Date(),
					failureDescription: error?.localizedDescription
				)

				self.store.saveOutcome(outcome)
				self.lastOutcome = outcome
				self.currentPlan = nil
				self.store.clearPlan()
			} else if reason != .none && plan.status == .armed {
				self.lastError = error?.localizedDescription ?? "Session was rejected by the system"
			}

			self.runtimeController.releaseSession()
			self.hasTriggered = false
			self.consecutiveAboveCount = 0
		}
	}
}
