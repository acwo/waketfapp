import SwiftUI

struct LastResultView: View {
	@EnvironmentObject var coordinator: AlarmCoordinator
	@Environment(\.dismiss) private var dismiss

	private var outcome: AlarmOutcome? { coordinator.lastOutcome }

	var body: some View {
		ScrollView {
			VStack(spacing: 10) {
				if let outcome {
					resultIcon(for: outcome.result)

					Text(outcome.localizedResultDescription)
						.font(.caption)
						.multilineTextAlignment(.center)

					Divider()

					VStack(alignment: .leading, spacing: 4) {
						detailRow(
							label: String(localized: "result_window", defaultValue: "Window"),
							value: "\(outcome.earliestDate.formatted(date: .omitted, time: .shortened)) - \(outcome.latestDate.formatted(date: .omitted, time: .shortened))"
						)

						detailRow(
							label: String(localized: "result_sensitivity", defaultValue: "Sensitivity"),
							value: outcome.sensitivity.localizedName
						)

						detailRow(
							label: String(localized: "result_mode", defaultValue: "Mode"),
							value: outcome.usedHeartRate
								? String(localized: "mode_hr", defaultValue: "Motion + Heart Rate")
								: String(localized: "mode_motion", defaultValue: "Motion only")
						)

						if let triggeredAt = outcome.triggeredAt {
							detailRow(
								label: String(localized: "result_triggered", defaultValue: "Triggered"),
								value: triggeredAt.formatted(date: .omitted, time: .shortened)
							)
						}
					}
				} else {
					Text(String(localized: "no_result", defaultValue: "No alarm result yet"))
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				Button(String(localized: "done_button", defaultValue: "Done")) {
					dismiss()
				}
				.padding(.top, 4)
			}
			.padding(.horizontal, 4)
		}
		.navigationTitle(String(localized: "result_title", defaultValue: "Last Result"))
	}

	@ViewBuilder
	private func resultIcon(for result: AlarmOutcome.AlarmResult) -> some View {
		switch result {
		case .triggeredEarly:
			Image(systemName: "sun.max.fill")
				.font(.title2)
				.foregroundStyle(.green)
		case .triggeredAtDeadline:
			Image(systemName: "alarm.fill")
				.font(.title2)
				.foregroundStyle(.orange)
		case .manuallyDisarmed:
			Image(systemName: "xmark.circle.fill")
				.font(.title2)
				.foregroundStyle(.secondary)
		case .sessionFailed:
			Image(systemName: "exclamationmark.triangle.fill")
				.font(.title2)
				.foregroundStyle(.red)
		}
	}

	private func detailRow(label: String, value: String) -> some View {
		HStack {
			Text(label)
				.font(.caption2)
				.foregroundStyle(.secondary)
			Spacer()
			Text(value)
				.font(.caption2)
		}
	}
}
