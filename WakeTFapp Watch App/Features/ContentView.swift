import SwiftUI

struct ContentView: View {
	@EnvironmentObject var coordinator: AlarmCoordinator

	var body: some View {
		Group {
			switch coordinator.currentPlan?.status {
			case .armed, .scheduling:
				ArmedView()
					.transition(.move(edge: .trailing).combined(with: .opacity))
			case .monitoring:
				MonitoringView()
					.transition(.opacity)
			case .alerting:
				AlertingView()
					.transition(.opacity)
			case .disarmed, .completed, .failed, nil:
				AlarmSetupView()
					.transition(.move(edge: .leading).combined(with: .opacity))
			}
		}
		.animation(.easeInOut(duration: 0.3), value: coordinator.currentPlan?.status)
	}
}
