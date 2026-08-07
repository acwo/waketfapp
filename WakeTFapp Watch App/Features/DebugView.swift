#if DEBUG
import SwiftUI

struct DebugView: View {
	@EnvironmentObject var coordinator: AlarmCoordinator
	@State private var shortWindowMinutes: Int = 2
	@State private var simulateMotionLevel: Double = 0.0
	@State private var simulateHeartRate: Double = 70.0

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 10) {
					Text("Debug Controls")
						.font(.headline)
						.foregroundStyle(.orange)

					Toggle("Debug Mode", isOn: $coordinator.isDebugMode)
						.font(.caption)

					Divider()

					Section {
						VStack(alignment: .leading, spacing: 4) {
							Text("Simulated Motion Level")
								.font(.caption2)
							Slider(value: $simulateMotionLevel, in: 0...2.5)
							Text(String(format: "%.2f g", simulateMotionLevel))
								.font(.caption2)
								.monospacedDigit()
						}

						Button("Apply Motion") {
							applySimulatedMotion()
						}
						.font(.caption)

						Button("Clear Motion") {
							coordinator.debugMotionFeatures = nil
						}
						.font(.caption)
					}

					Divider()

					Section {
						VStack(alignment: .leading, spacing: 4) {
							Text("Simulated Heart Rate")
								.font(.caption2)
							Slider(value: $simulateHeartRate, in: 40...120)
							Text(String(format: "%.0f BPM", simulateHeartRate))
								.font(.caption2)
								.monospacedDigit()
						}

						Button("Apply Heart Rate") {
							applySimulatedHeartRate()
						}
						.font(.caption)

						Button("Clear Heart Rate") {
							coordinator.debugHeartRateFeatures = nil
						}
						.font(.caption)
					}

					Divider()

					Section {
						Text("Quick Actions")
							.font(.caption2)
							.foregroundStyle(.secondary)

						Button("Force Strong Burst") {
							forceStrongBurst()
						}
						.font(.caption)
						.buttonStyle(.borderedProminent)
						.tint(.orange)

						Button("Force Deadline Trigger") {
							forceDeadline()
						}
						.font(.caption)
						.buttonStyle(.bordered)
					}

					Divider()

					VStack(alignment: .leading, spacing: 2) {
						Text("State: \(coordinator.currentPlan?.status.rawValue ?? "none")")
							.font(.caption2)
						Text("Score: \(String(format: "%.3f", coordinator.currentScore.combinedScore))")
							.font(.caption2)
						Text("Motion: \(String(format: "%.3f", coordinator.currentScore.motionScore))")
							.font(.caption2)
						Text("HR: \(String(format: "%.3f", coordinator.currentScore.heartRateScore))")
							.font(.caption2)
						Text("Above: \(coordinator.currentScore.isAboveThreshold ? "YES" : "no")")
							.font(.caption2)
					}
					.monospacedDigit()
				}
				.padding(.horizontal, 4)
			}
			.navigationTitle("Debug")
		}
	}

	private func applySimulatedMotion() {
		coordinator.debugMotionFeatures = MotionFeatures(
			rmsAcceleration: simulateMotionLevel * 0.3,
			accelerationVariance: simulateMotionLevel * 0.1,
			peakMagnitude: simulateMotionLevel,
			movementBurstCount: simulateMotionLevel > 0.5 ? Int(simulateMotionLevel * 3) : 0,
			timeSinceLastBurst: simulateMotionLevel > 0.5 ? 2.0 : nil,
			orientationChangeMagnitude: simulateMotionLevel * 0.5,
			sampleCount: 50,
			windowDuration: 15.0
		)
	}

	private func applySimulatedHeartRate() {
		coordinator.debugHeartRateFeatures = HeartRateFeatures(
			currentBPM: simulateHeartRate,
			baselineBPM: 62.0,
			riseFromBaseline: simulateHeartRate - 62.0,
			trend: simulateHeartRate > 70 ? .rising : .stable,
			sampleFreshness: 30.0,
			sampleCount: 5
		)
	}

	private func forceStrongBurst() {
		coordinator.debugMotionFeatures = MotionFeatures(
			rmsAcceleration: 1.5,
			accelerationVariance: 0.8,
			peakMagnitude: 2.5,
			movementBurstCount: 8,
			timeSinceLastBurst: 1.0,
			orientationChangeMagnitude: 1.8,
			sampleCount: 100,
			windowDuration: 15.0
		)
	}

	private func forceDeadline() {
		coordinator.debugMotionFeatures = MotionFeatures.empty
		coordinator.debugHeartRateFeatures = .unavailable
	}
}
#endif
