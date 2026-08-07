import SwiftUI

struct AlertingView: View {
	@EnvironmentObject var coordinator: AlarmCoordinator

	private var plan: AlarmPlan? { coordinator.currentPlan }

	var body: some View {
		VStack(spacing: 14) {
			Image(systemName: "sun.max.fill")
				.font(.largeTitle)
				.foregroundStyle(.yellow)
				.symbolEffect(.bounce, options: .repeating)

			Text(String(localized: "wakeup_title", defaultValue: "Wake up"))
				.font(.title3)
				.fontWeight(.bold)

			if let plan {
				VStack(spacing: 4) {
					if let triggeredAt = plan.triggeredAt {
						Text(triggeredAt, style: .time)
							.font(.callout)
					}

					if let reason = plan.triggerReason {
						Text(reason.localizedDescription)
							.font(.caption2)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
					}
				}
			}

			Button(action: { coordinator.stopAlarm() }) {
				Text(String(localized: "stop_button", defaultValue: "Stop"))
					.font(.title3)
					.fontWeight(.bold)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 8)
			}
			.buttonStyle(.borderedProminent)
			.tint(.red)
			.accessibilityLabel("Stop alarm")
			.accessibilityHint("Stops the repeating haptic alarm")
		}
		.padding(.horizontal, 4)
	}
}
