import Foundation

struct AggregatedFeatures: Sendable {
	let motionFeatures: MotionFeatures
	let heartRateFeatures: HeartRateFeatures
	let elapsedSinceStart: TimeInterval
	let windowIndex: Int
	let timestamp: Date

	var hasMotion: Bool {
		motionFeatures.sampleCount > 0
	}

	var hasHeartRate: Bool {
		heartRateFeatures.isFresh
	}
}

actor WakeFeatureAggregator {
	private var history: [AggregatedFeatures] = []
	private let maxHistory = 20

	func aggregate(
		motion: MotionFeatures,
		heartRate: HeartRateFeatures,
		elapsedSinceStart: TimeInterval,
		windowIndex: Int
	) -> AggregatedFeatures {
		let features = AggregatedFeatures(
			motionFeatures: motion,
			heartRateFeatures: heartRate,
			elapsedSinceStart: elapsedSinceStart,
			windowIndex: windowIndex,
			timestamp: Date()
		)

		history.append(features)
		if history.count > maxHistory {
			history.removeFirst()
		}

		return features
	}

	func reset() {
		history.removeAll()
	}

	func recentHistory(count: Int = 5) -> [AggregatedFeatures] {
		Array(history.suffix(count))
	}
}
