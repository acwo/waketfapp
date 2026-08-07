import SwiftUI

struct MonitoringView: View {
	@EnvironmentObject var coordinator: AlarmCoordinator

	private var plan: AlarmPlan? { coordinator.currentPlan }

	var body: some View {
		VStack(spacing: 12) {
			Image(systemName: "waveform.path")
				.font(.title2)
				.foregroundStyle(.cyan)
				.symbolEffect(.pulse)

			Text(String(localized: "monitoring_title", defaultValue: "Finding a wake moment"))
				.font(.caption)
				.multilineTextAlignment(.center)

			if let plan {
				VStack(spacing: 4) {
					Text(String(localized: "latest_alarm_label", defaultValue: "Latest alarm"))
						.font(.caption2)
						.foregroundStyle(.secondary)
					Text(plan.latestDate, style: .time)
						.font(.callout)
						.fontWeight(.medium)
				}
			}

			sensorStatusView

			#if DEBUG
			if coordinator.isDebugMode {
				debugScoreView
			}
			#endif

			Button(role: .destructive) {
				coordinator.disarm()
			} label: {
				Text(String(localized: "disarm_button", defaultValue: "Disarm"))
					.font(.caption)
			}
			.buttonStyle(.bordered)
		}
		.padding(.horizontal, 4)
	}

	private var sensorStatusView: some View {
		HStack(spacing: 6) {
			switch coordinator.sensorStatus {
			case .motionAndHeartRate:
				Image(systemName: "figure.walk")
					.foregroundStyle(.green)
				Image(systemName: "heart.fill")
					.foregroundStyle(.red)
			case .motionOnly:
				Image(systemName: "figure.walk")
					.foregroundStyle(.green)
				Image(systemName: "heart.slash")
					.foregroundStyle(.secondary)
			case .noSensors:
				Image(systemName: "exclamationmark.triangle")
					.foregroundStyle(.yellow)
			case .idle:
				EmptyView()
			}
		}
		.font(.caption)
	}

	#if DEBUG
	private var debugScoreView: some View {
		VStack(spacing: 2) {
			Text("Score: \(String(format: "%.2f", coordinator.currentScore.combinedScore))")
				.font(.caption2)
				.monospacedDigit()
			Text("Threshold: \(String(format: "%.2f", coordinator.currentScore.sensitivity.threshold))")
				.font(.caption2)
				.monospacedDigit()
				.foregroundStyle(.secondary)
		}
	}
	#endif
}
