import SwiftUI
import HealthKit

struct AlarmSetupView: View {
	@EnvironmentObject var coordinator: AlarmCoordinator
	@State private var earliestHour: Int = 9
	@State private var earliestMinute: Int = 30
	@State private var latestHour: Int = 10
	@State private var latestMinute: Int = 0
	@State private var sensitivity: Sensitivity = .normal
	@State private var useHeartRate: Bool = true
	@State private var errorMessage: String?
	@State private var isArming: Bool = false
	@State private var showLastResult: Bool = false
	#if DEBUG
	@State private var showDebug: Bool = false
	#endif

	private var windowDuration: Int {
		let earliestMinutes = earliestHour * 60 + earliestMinute
		var latestMinutes = latestHour * 60 + latestMinute
		if latestMinutes <= earliestMinutes {
			latestMinutes += 24 * 60
		}
		return latestMinutes - earliestMinutes
	}

	private var isWindowValid: Bool {
		windowDuration >= 5 && windowDuration <= 30
	}

	private var healthPermissionStatus: String {
		guard HKHealthStore.isHealthDataAvailable() else { return "Not available" }
		if coordinator.hasRequestedHealthAuth {
			return "Enabled"
		}
		return "Will ask on arm"
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 12) {
					timeSection
					durationInfo
					settingsSection
					permissionStatus
					platformNote
					validationMessage
					armButton
					lastResultButton
				}
				.padding(.horizontal, 4)
			}
			.navigationTitle(String(localized: "app_title", defaultValue: "WakeTFapp"))
			.sheet(isPresented: $showLastResult) {
				LastResultView()
			}
			#if DEBUG
			.sheet(isPresented: $showDebug) {
				DebugView()
			}
			#endif
		}
	}

	private var timeSection: some View {
		VStack(spacing: 8) {
			HStack {
				Text(String(localized: "earliest_label", defaultValue: "Earliest"))
					.font(.caption)
					.foregroundStyle(.secondary)
				Spacer()
			}
			HStack {
				Picker("Hour", selection: $earliestHour) {
					ForEach(0..<24, id: \.self) { h in
						Text(String(format: "%02d", h)).tag(h)
					}
				}
				.frame(width: 60, height: 70)
				.accessibilityLabel("Earliest hour")
				Text(":")
					.font(.title3)
				Picker("Minute", selection: $earliestMinute) {
					ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
						Text(String(format: "%02d", m)).tag(m)
					}
				}
				.frame(width: 60, height: 70)
				.accessibilityLabel("Earliest minute")
			}

			HStack {
				Text(String(localized: "latest_label", defaultValue: "Latest"))
					.font(.caption)
					.foregroundStyle(.secondary)
				Spacer()
			}
			HStack {
				Picker("Hour", selection: $latestHour) {
					ForEach(0..<24, id: \.self) { h in
						Text(String(format: "%02d", h)).tag(h)
					}
				}
				.frame(width: 60, height: 70)
				.accessibilityLabel("Latest hour")
				Text(":")
					.font(.title3)
				Picker("Minute", selection: $latestMinute) {
					ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
						Text(String(format: "%02d", m)).tag(m)
					}
				}
				.frame(width: 60, height: 70)
				.accessibilityLabel("Latest minute")
			}
		}
	}

	private var durationInfo: some View {
		HStack {
			Text(String(localized: "window_label", defaultValue: "Window:"))
				.font(.caption)
				.foregroundStyle(.secondary)
			Text("\(windowDuration) min")
				.font(.callout)
				.fontWeight(.medium)
				.foregroundStyle(isWindowValid ? Color.primary : Color.red)
				.accessibilityValue("\(windowDuration) minutes")
			Spacer()
		}
	}

	private var settingsSection: some View {
		VStack(spacing: 8) {
			Picker(
				String(localized: "sensitivity_label", defaultValue: "Sensitivity"),
				selection: $sensitivity
			) {
				ForEach(Sensitivity.allCases) { s in
					Text(s.localizedName).tag(s)
				}
			}
			.accessibilityHint(sensitivity.localizedDescription)

			Text(sensitivity.localizedDescription)
				.font(.caption2)
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity, alignment: .leading)

			Toggle(
				String(localized: "heart_rate_toggle", defaultValue: "Use Heart Rate"),
				isOn: $useHeartRate
			)
			.font(.caption)
			.accessibilityHint("When enabled, heart rate data helps detect waking")
		}
	}

	private var permissionStatus: some View {
		VStack(alignment: .leading, spacing: 2) {
			HStack(spacing: 4) {
				Image(systemName: "figure.walk")
					.font(.caption2)
				Text("Motion: Available")
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
			if useHeartRate {
				HStack(spacing: 4) {
					Image(systemName: "heart.fill")
						.font(.caption2)
						.foregroundStyle(.pink)
					Text("Heart Rate: \(healthPermissionStatus)")
						.font(.caption2)
						.foregroundStyle(.secondary)
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var platformNote: some View {
		Text(String(localized: "platform_note", defaultValue: "Max 30-min window (watchOS limit)"))
			.font(.caption2)
			.foregroundStyle(.secondary)
			.frame(maxWidth: .infinity, alignment: .leading)
	}

	@ViewBuilder
	private var validationMessage: some View {
		if windowDuration > 30 {
			Text(String(localized: "validation_30min", defaultValue: "watchOS supports a maximum 30-minute smart wake window. Choose a later earliest time or an earlier latest time."))
				.font(.caption2)
				.foregroundStyle(.red)
				.multilineTextAlignment(.center)
		} else if windowDuration < 5 {
			Text(String(localized: "validation_5min", defaultValue: "Wake window must be at least 5 minutes."))
				.font(.caption2)
				.foregroundStyle(.red)
				.multilineTextAlignment(.center)
		}

		if let errorMessage {
			Text(errorMessage)
				.font(.caption2)
				.foregroundStyle(.red)
				.multilineTextAlignment(.center)
		}
	}

	private var armButton: some View {
		Button(action: armAlarm) {
			HStack {
				if isArming {
					ProgressView()
						.tint(.black)
				}
				Text(String(localized: "arm_button", defaultValue: "Arm"))
					.fontWeight(.semibold)
			}
			.frame(maxWidth: .infinity)
		}
		.buttonStyle(.borderedProminent)
		.tint(.green)
		.disabled(!isWindowValid || isArming)
		.accessibilityLabel("Arm alarm")
		.accessibilityHint("Schedules the smart alarm for the selected window")
	}

	@ViewBuilder
	private var lastResultButton: some View {
		if coordinator.lastOutcome != nil {
			Button(String(localized: "last_result_button", defaultValue: "Last Result")) {
				showLastResult = true
			}
			.font(.caption)
			.accessibilityLabel("View last alarm result")
		}
		#if DEBUG
		Button("Debug") {
			showDebug = true
		}
		.font(.caption2)
		.foregroundStyle(.orange)
		#endif
	}

	private func armAlarm() {
		isArming = true
		errorMessage = nil

		Task {
			let result = await coordinator.armAlarm(
				earliestHour: earliestHour,
				earliestMinute: earliestMinute,
				latestHour: latestHour,
				latestMinute: latestMinute,
				sensitivity: sensitivity,
				useHeartRate: useHeartRate
			)

			isArming = false

			switch result {
			case .success:
				break
			case .failure(let error):
				errorMessage = error.localizedDescription
			}
		}
	}
}
