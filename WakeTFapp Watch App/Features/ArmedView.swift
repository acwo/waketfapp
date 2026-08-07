import SwiftUI

struct ArmedView: View {
	@EnvironmentObject var coordinator: AlarmCoordinator
	@State private var countdown: String = "--:--"
	@State private var timer: Timer?

	private var plan: AlarmPlan? { coordinator.currentPlan }

	var body: some View {
		ScrollView {
			VStack(spacing: 10) {
				Image(systemName: "alarm.fill")
					.font(.system(size: 32))
					.foregroundStyle(.green)
					.padding(.top, 4)

				Text("Alarm Active")
					.font(.headline)
					.foregroundStyle(.green)

				if let plan {
					HStack(spacing: 4) {
						Text(plan.earliestDate, style: .time)
						Text("-")
						Text(plan.latestDate, style: .time)
					}
					.font(.title3)
					.fontWeight(.medium)

					Text(plan.earliestDate, style: .date)
						.font(.caption2)
						.foregroundStyle(.secondary)

					Divider()

					VStack(spacing: 4) {
						Text("Starts in")
							.font(.caption2)
							.foregroundStyle(.secondary)
						Text(countdown)
							.font(.title3)
							.fontWeight(.semibold)
							.monospacedDigit()
							.foregroundStyle(.green)
					}

					Divider()

					VStack(spacing: 4) {
						HStack(spacing: 4) {
							Image(systemName: plan.useHeartRate ? "heart.fill" : "figure.walk")
								.font(.caption2)
								.foregroundStyle(plan.useHeartRate ? .pink : .blue)
							Text(plan.useHeartRate ? "Motion + Heart Rate" : "Motion only")
								.font(.caption2)
						}
						HStack(spacing: 4) {
							Image(systemName: "dial.low")
								.font(.caption2)
							Text("Sensitivity: \(plan.sensitivity.localizedName)")
								.font(.caption2)
						}
						Text("\(plan.windowDurationMinutes) min window")
							.font(.caption2)
					}
					.foregroundStyle(.secondary)
				}

				if let error = coordinator.lastError {
					VStack(spacing: 4) {
						Image(systemName: "exclamationmark.triangle.fill")
							.foregroundStyle(.yellow)
						Text(error)
							.font(.caption2)
							.foregroundStyle(.yellow)
							.multilineTextAlignment(.center)
					}
					.padding(.vertical, 4)
				}

				Button(role: .destructive) {
					coordinator.disarm()
				} label: {
					Text("Cancel Alarm")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.bordered)
				.padding(.top, 6)
			}
			.padding(.horizontal, 4)
		}
		.onAppear { startCountdownTimer() }
		.onDisappear { timer?.invalidate() }
	}

	private func startCountdownTimer() {
		updateCountdown()
		timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
			Task { @MainActor in
				updateCountdown()
			}
		}
	}

	private func updateCountdown() {
		guard let earliest = plan?.earliestDate else {
			countdown = "--:--"
			return
		}
		let interval = earliest.timeIntervalSinceNow
		if interval <= 0 {
			countdown = "Starting..."
			return
		}
		let hours = Int(interval) / 3600
		let minutes = (Int(interval) % 3600) / 60
		if hours > 0 {
			countdown = "\(hours)h \(minutes)m"
		} else {
			countdown = "\(minutes)m"
		}
	}
}
