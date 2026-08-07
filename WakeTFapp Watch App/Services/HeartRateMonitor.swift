import Foundation
import HealthKit

struct HeartRateFeatures: Sendable {
	let currentBPM: Double?
	let baselineBPM: Double?
	let riseFromBaseline: Double?
	let trend: HeartRateTrend
	let sampleFreshness: TimeInterval?
	let sampleCount: Int

	static let unavailable = HeartRateFeatures(
		currentBPM: nil,
		baselineBPM: nil,
		riseFromBaseline: nil,
		trend: .unknown,
		sampleCount: 0
	)

	init(
		currentBPM: Double? = nil,
		baselineBPM: Double? = nil,
		riseFromBaseline: Double? = nil,
		trend: HeartRateTrend = .unknown,
		sampleFreshness: TimeInterval? = nil,
		sampleCount: Int = 0
	) {
		self.currentBPM = currentBPM
		self.baselineBPM = baselineBPM
		self.riseFromBaseline = riseFromBaseline
		self.trend = trend
		self.sampleFreshness = sampleFreshness
		self.sampleCount = sampleCount
	}

	var isFresh: Bool {
		guard let freshness = sampleFreshness else { return false }
		return freshness < HeartRateMonitor.freshnessLimit
	}
}

enum HeartRateTrend: String, Sendable {
	case rising
	case stable
	case falling
	case unknown
}

protocol HeartRateMonitorProtocol: Sendable {
	func requestAuthorization() async -> Bool
	func startMonitoring() async
	func stopMonitoring()
	func currentFeatures() -> HeartRateFeatures
	var isAuthorized: Bool { get }
	var isAvailable: Bool { get }
}

final class HeartRateMonitor: HeartRateMonitorProtocol, @unchecked Sendable {
	static let freshnessLimit: TimeInterval = 300

	private let healthStore: HKHealthStore
	private let heartRateType: HKQuantityType
	private var query: HKAnchoredObjectQuery?
	private var samples: [(bpm: Double, date: Date)] = []
	private let maxSamples = 20
	private let lock = NSLock()

	var isAvailable: Bool {
		HKHealthStore.isHealthDataAvailable()
	}

	var isAuthorized: Bool {
		let status = healthStore.authorizationStatus(for: heartRateType)
		return status != .sharingDenied
	}

	init() {
		self.healthStore = HKHealthStore()
		self.heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
	}

	func requestAuthorization() async -> Bool {
		guard isAvailable else { return false }
		let readTypes: Set<HKObjectType> = [heartRateType]
		do {
			try await healthStore.requestAuthorization(toShare: [], read: readTypes)
			return true
		} catch {
			return false
		}
	}

	func startMonitoring() async {
		guard isAvailable else { return }

		let predicate = HKQuery.predicateForSamples(
			withStart: Date().addingTimeInterval(-Self.freshnessLimit),
			end: nil,
			options: .strictStartDate
		)

		let query = HKAnchoredObjectQuery(
			type: heartRateType,
			predicate: predicate,
			anchor: nil,
			limit: HKObjectQueryNoLimit
		) { [weak self] _, newSamples, _, _, _ in
			self?.processSamples(newSamples)
		}

		query.updateHandler = { [weak self] _, newSamples, _, _, _ in
			self?.processSamples(newSamples)
		}

		self.query = query
		healthStore.execute(query)
	}

	func stopMonitoring() {
		if let query {
			healthStore.stop(query)
			self.query = nil
		}
		lock.lock()
		samples.removeAll()
		lock.unlock()
	}

	func currentFeatures() -> HeartRateFeatures {
		lock.lock()
		let currentSamples = samples
		lock.unlock()

		guard !currentSamples.isEmpty else { return .unavailable }

		let now = Date()
		let freshSamples = currentSamples.filter {
			now.timeIntervalSince($0.date) < Self.freshnessLimit
		}

		guard let latest = freshSamples.last else { return .unavailable }

		let freshness = now.timeIntervalSince(latest.date)
		let currentBPM = latest.bpm

		let baseline: Double?
		if freshSamples.count >= 3 {
			let sorted = freshSamples.map(\.bpm).sorted()
			baseline = sorted[sorted.count / 2]
		} else {
			baseline = nil
		}

		let rise: Double?
		if let baseline {
			rise = currentBPM - baseline
		} else {
			rise = nil
		}

		let trend: HeartRateTrend
		if freshSamples.count >= 3 {
			let recent = freshSamples.suffix(3).map(\.bpm)
			let diffs = zip(recent.dropFirst(), recent).map { $0 - $1 }
			let avgDiff = diffs.reduce(0, +) / Double(diffs.count)
			if avgDiff > 2.0 {
				trend = .rising
			} else if avgDiff < -2.0 {
				trend = .falling
			} else {
				trend = .stable
			}
		} else {
			trend = .unknown
		}

		return HeartRateFeatures(
			currentBPM: currentBPM,
			baselineBPM: baseline,
			riseFromBaseline: rise,
			trend: trend,
			sampleFreshness: freshness,
			sampleCount: freshSamples.count
		)
	}

	private func processSamples(_ newSamples: [HKSample]?) {
		guard let quantitySamples = newSamples as? [HKQuantitySample] else { return }

		let bpmUnit = HKUnit.count().unitDivided(by: .minute())
		let newEntries = quantitySamples.map { sample in
			(bpm: sample.quantity.doubleValue(for: bpmUnit), date: sample.startDate)
		}

		lock.lock()
		samples.append(contentsOf: newEntries)
		if samples.count > maxSamples {
			samples = Array(samples.suffix(maxSamples))
		}
		lock.unlock()
	}
}
