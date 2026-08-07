import Foundation

enum AlarmTriggerReason: String, Codable, Sendable {
	case motionDetected
	case motionAndHeartRate
	case strongMovementBurst
	case latestTimeFallback
	case sessionWillExpireFallback
	case expirationSafetyFallback
}

extension AlarmTriggerReason {
	var localizedDescription: String {
		switch self {
		case .motionDetected:
			return String(localized: "trigger_motion", defaultValue: "Wrist movement detected")
		case .motionAndHeartRate:
			return String(localized: "trigger_motion_hr", defaultValue: "Movement and heart rate rise detected")
		case .strongMovementBurst:
			return String(localized: "trigger_burst", defaultValue: "Strong movement detected")
		case .latestTimeFallback:
			return String(localized: "trigger_latest", defaultValue: "Latest wake time reached")
		case .sessionWillExpireFallback:
			return String(localized: "trigger_expiry", defaultValue: "Wake window ending")
		case .expirationSafetyFallback:
			return String(localized: "trigger_safety", defaultValue: "Safety deadline reached")
		}
	}
}
