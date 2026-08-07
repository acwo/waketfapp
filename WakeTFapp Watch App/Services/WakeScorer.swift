import Foundation

struct WakeScore: Sendable, Equatable {
	let motionScore: Double
	let heartRateScore: Double
	let combinedScore: Double
	let isAboveThreshold: Bool
	let sensitivity: Sensitivity
	let isStrongBurst: Bool

	static let zero = WakeScore(
		motionScore: 0,
		heartRateScore: 0,
		combinedScore: 0,
		isAboveThreshold: false,
		sensitivity: .normal,
		isStrongBurst: false
	)
}

struct WakeScorer: Sendable {
	private let strongBurstThreshold: Double = 1.2
	private let warmupDuration: TimeInterval = 150
	private let strongBurstBypassThreshold: Double = 2.0

	struct Baseline: Sendable {
		let motionRMSMedian: Double
		let motionRMSMAD: Double
		let heartRateMedian: Double?

		static let initial = Baseline(motionRMSMedian: 0.02, motionRMSMAD: 0.01, heartRateMedian: nil)
	}

	func calculateScore(
		features: AggregatedFeatures,
		baseline: Baseline,
		sensitivity: Sensitivity,
		consecutiveAboveCount: Int
	) -> WakeScore {
		let motionScore = calculateMotionScore(features: features.motionFeatures, baseline: baseline)
		let heartRateScore = calculateHeartRateScore(features: features.heartRateFeatures, baseline: baseline)

		let combinedScore: Double
		if features.hasMotion && features.hasHeartRate {
			combinedScore = motionScore * 0.75 + heartRateScore * 0.25
		} else if features.hasMotion {
			combinedScore = motionScore
		} else {
			combinedScore = 0
		}

		let isStrongBurst = features.motionFeatures.peakMagnitude >= strongBurstBypassThreshold

		let isAboveThreshold: Bool
		if isStrongBurst && features.elapsedSinceStart > 30 {
			isAboveThreshold = true
		} else if features.elapsedSinceStart < warmupDuration && !isStrongBurst {
			isAboveThreshold = false
		} else {
			isAboveThreshold = combinedScore >= sensitivity.threshold
		}

		return WakeScore(
			motionScore: motionScore,
			heartRateScore: heartRateScore,
			combinedScore: combinedScore,
			isAboveThreshold: isAboveThreshold,
			sensitivity: sensitivity,
			isStrongBurst: isStrongBurst
		)
	}

	func updateBaseline(history: [AggregatedFeatures], current: Baseline) -> Baseline {
		guard history.count >= 3 else { return current }

		let rmsValues = history.map(\.motionFeatures.rmsAcceleration).sorted()
		let motionMedian = rmsValues[rmsValues.count / 2]
		let deviations = rmsValues.map { abs($0 - motionMedian) }.sorted()
		let mad = deviations[deviations.count / 2]

		let hrMedian: Double?
		let hrValues = history.compactMap(\.heartRateFeatures.currentBPM).sorted()
		if hrValues.count >= 3 {
			hrMedian = hrValues[hrValues.count / 2]
		} else {
			hrMedian = current.heartRateMedian
		}

		return Baseline(
			motionRMSMedian: motionMedian,
			motionRMSMAD: max(mad, 0.005),
			heartRateMedian: hrMedian
		)
	}

	private func calculateMotionScore(features: MotionFeatures, baseline: Baseline) -> Double {
		guard features.sampleCount > 0 else { return 0 }

		let rmsComponent: Double
		if baseline.motionRMSMAD > 0 {
			let deviation = (features.rmsAcceleration - baseline.motionRMSMedian) / baseline.motionRMSMAD
			rmsComponent = min(max(deviation / 5.0, 0), 1.0)
		} else {
			rmsComponent = min(features.rmsAcceleration / 0.3, 1.0)
		}

		let burstComponent = min(Double(features.movementBurstCount) / 5.0, 1.0)

		let peakComponent = min(features.peakMagnitude / strongBurstThreshold, 1.0)

		let orientationComponent = min(features.orientationChangeMagnitude / 2.0, 1.0)

		return rmsComponent * 0.35 + burstComponent * 0.25 + peakComponent * 0.25 + orientationComponent * 0.15
	}

	private func calculateHeartRateScore(features: HeartRateFeatures, baseline: Baseline) -> Double {
		guard features.isFresh, let currentBPM = features.currentBPM else { return 0 }

		var score: Double = 0

		if let baselineBPM = features.baselineBPM ?? baseline.heartRateMedian {
			let rise = currentBPM - baselineBPM
			let riseComponent = min(max(rise / 15.0, 0), 1.0)
			score += riseComponent * 0.6
		}

		switch features.trend {
		case .rising:
			score += 0.4
		case .stable:
			score += 0.1
		case .falling, .unknown:
			break
		}

		return min(score, 1.0)
	}
}
