import XCTest
@testable import WakeTFapp_Watch_App

final class WakeScorerTests: XCTestCase {
	private var scorer: WakeScorer!

	override func setUp() {
		super.setUp()
		scorer = WakeScorer()
	}

	func testMotionOnlyBaseline_NoTrigger() {
		let features = makeAggregated(
			rms: 0.02, variance: 0.005, peak: 0.05, bursts: 0,
			elapsedSinceStart: 200, windowIndex: 10
		)
		let baseline = WakeScorer.Baseline(motionRMSMedian: 0.02, motionRMSMAD: 0.01, heartRateMedian: nil)

		let score = scorer.calculateScore(
			features: features, baseline: baseline,
			sensitivity: .normal, consecutiveAboveCount: 0
		)

		XCTAssertFalse(score.isAboveThreshold)
		XCTAssertLessThan(score.combinedScore, 0.3)
	}

	func testMotionOnlyEarlyTrigger() {
		let features = makeAggregated(
			rms: 0.4, variance: 0.2, peak: 0.9, bursts: 4,
			elapsedSinceStart: 200, windowIndex: 12
		)
		let baseline = WakeScorer.Baseline(motionRMSMedian: 0.02, motionRMSMAD: 0.01, heartRateMedian: nil)

		let score = scorer.calculateScore(
			features: features, baseline: baseline,
			sensitivity: .normal, consecutiveAboveCount: 1
		)

		XCTAssertTrue(score.isAboveThreshold)
		XCTAssertGreaterThan(score.combinedScore, 0.68)
	}

	func testStaleHeartRateIgnored() {
		let hrFeatures = HeartRateFeatures(
			currentBPM: 85.0,
			baselineBPM: 62.0,
			riseFromBaseline: 23.0,
			trend: .rising,
			sampleFreshness: 400.0,
			sampleCount: 3
		)

		let aggregated = AggregatedFeatures(
			motionFeatures: makeMotion(rms: 0.1, variance: 0.05, peak: 0.3, bursts: 1),
			heartRateFeatures: hrFeatures,
			elapsedSinceStart: 200,
			windowIndex: 10,
			timestamp: Date()
		)

		let baseline = WakeScorer.Baseline(motionRMSMedian: 0.02, motionRMSMAD: 0.01, heartRateMedian: 62.0)

		let score = scorer.calculateScore(
			features: aggregated, baseline: baseline,
			sensitivity: .normal, consecutiveAboveCount: 0
		)

		XCTAssertEqual(score.heartRateScore, 0.0, "Stale HR should contribute zero")
	}

	func testFreshHeartRateContributes() {
		let hrFeatures = HeartRateFeatures(
			currentBPM: 80.0,
			baselineBPM: 62.0,
			riseFromBaseline: 18.0,
			trend: .rising,
			sampleFreshness: 30.0,
			sampleCount: 5
		)

		let aggregated = AggregatedFeatures(
			motionFeatures: makeMotion(rms: 0.15, variance: 0.08, peak: 0.4, bursts: 2),
			heartRateFeatures: hrFeatures,
			elapsedSinceStart: 200,
			windowIndex: 12,
			timestamp: Date()
		)

		let baseline = WakeScorer.Baseline(motionRMSMedian: 0.02, motionRMSMAD: 0.01, heartRateMedian: 62.0)

		let score = scorer.calculateScore(
			features: aggregated, baseline: baseline,
			sensitivity: .normal, consecutiveAboveCount: 0
		)

		XCTAssertGreaterThan(score.heartRateScore, 0.0)
		XCTAssertGreaterThan(score.combinedScore, score.motionScore * 0.75)
	}

	func testNoTriggerDuringWarmup() {
		let features = makeAggregated(
			rms: 0.3, variance: 0.15, peak: 0.7, bursts: 3,
			elapsedSinceStart: 60, windowIndex: 3
		)
		let baseline = WakeScorer.Baseline(motionRMSMedian: 0.02, motionRMSMAD: 0.01, heartRateMedian: nil)

		let score = scorer.calculateScore(
			features: features, baseline: baseline,
			sensitivity: .high, consecutiveAboveCount: 1
		)

		XCTAssertFalse(score.isAboveThreshold, "Should not trigger during warmup")
	}

	func testStrongBurstBypassesWarmup() {
		let features = makeAggregated(
			rms: 1.5, variance: 0.8, peak: 2.5, bursts: 8,
			elapsedSinceStart: 60, windowIndex: 3
		)
		let baseline = WakeScorer.Baseline(motionRMSMedian: 0.02, motionRMSMAD: 0.01, heartRateMedian: nil)

		let score = scorer.calculateScore(
			features: features, baseline: baseline,
			sensitivity: .normal, consecutiveAboveCount: 0
		)

		XCTAssertTrue(score.isStrongBurst)
		XCTAssertTrue(score.isAboveThreshold)
	}

	func testTwoConsecutiveWindowsRequired() {
		let features = makeAggregated(
			rms: 0.35, variance: 0.15, peak: 0.8, bursts: 3,
			elapsedSinceStart: 200, windowIndex: 10
		)
		let baseline = WakeScorer.Baseline(motionRMSMedian: 0.02, motionRMSMAD: 0.01, heartRateMedian: nil)

		let scoreFirst = scorer.calculateScore(
			features: features, baseline: baseline,
			sensitivity: .normal, consecutiveAboveCount: 0
		)

		let scoreSecond = scorer.calculateScore(
			features: features, baseline: baseline,
			sensitivity: .normal, consecutiveAboveCount: 1
		)

		if scoreFirst.combinedScore >= Sensitivity.normal.threshold {
			XCTAssertTrue(scoreFirst.isAboveThreshold)
			XCTAssertTrue(scoreSecond.isAboveThreshold)
		}
	}

	func testSensitivityThresholdsOrder() {
		let features = makeAggregated(
			rms: 0.25, variance: 0.1, peak: 0.6, bursts: 2,
			elapsedSinceStart: 200, windowIndex: 10
		)
		let baseline = WakeScorer.Baseline(motionRMSMedian: 0.02, motionRMSMAD: 0.01, heartRateMedian: nil)

		let scoreLow = scorer.calculateScore(
			features: features, baseline: baseline,
			sensitivity: .low, consecutiveAboveCount: 1
		)
		let scoreNormal = scorer.calculateScore(
			features: features, baseline: baseline,
			sensitivity: .normal, consecutiveAboveCount: 1
		)
		let scoreHigh = scorer.calculateScore(
			features: features, baseline: baseline,
			sensitivity: .high, consecutiveAboveCount: 1
		)

		XCTAssertEqual(scoreLow.combinedScore, scoreNormal.combinedScore)
		XCTAssertEqual(scoreNormal.combinedScore, scoreHigh.combinedScore)

		XCTAssertGreaterThan(Sensitivity.low.threshold, Sensitivity.normal.threshold)
		XCTAssertGreaterThan(Sensitivity.normal.threshold, Sensitivity.high.threshold)
	}

	func testBaselineUpdate() {
		let history = (0..<5).map { i in
			makeAggregated(
				rms: 0.02 + Double(i) * 0.001,
				variance: 0.005,
				peak: 0.05,
				bursts: 0,
				elapsedSinceStart: Double(i) * 15,
				windowIndex: i
			)
		}

		let newBaseline = scorer.updateBaseline(history: history, current: .initial)
		XCTAssertGreaterThan(newBaseline.motionRMSMedian, 0)
		XCTAssertGreaterThan(newBaseline.motionRMSMAD, 0)
	}

	private func makeMotion(rms: Double, variance: Double, peak: Double, bursts: Int) -> MotionFeatures {
		MotionFeatures(
			rmsAcceleration: rms,
			accelerationVariance: variance,
			peakMagnitude: peak,
			movementBurstCount: bursts,
			timeSinceLastBurst: bursts > 0 ? 3.0 : nil,
			orientationChangeMagnitude: rms * 1.5,
			sampleCount: 50,
			windowDuration: 15.0
		)
	}

	private func makeAggregated(
		rms: Double, variance: Double, peak: Double, bursts: Int,
		elapsedSinceStart: TimeInterval, windowIndex: Int
	) -> AggregatedFeatures {
		AggregatedFeatures(
			motionFeatures: makeMotion(rms: rms, variance: variance, peak: peak, bursts: bursts),
			heartRateFeatures: .unavailable,
			elapsedSinceStart: elapsedSinceStart,
			windowIndex: windowIndex,
			timestamp: Date()
		)
	}
}
