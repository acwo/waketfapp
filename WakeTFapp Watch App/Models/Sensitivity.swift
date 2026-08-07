import Foundation

enum Sensitivity: String, Codable, CaseIterable, Sendable, Identifiable {
	case low
	case normal
	case high

	var id: String { rawValue }

	var threshold: Double {
		switch self {
		case .low: return 0.80
		case .normal: return 0.68
		case .high: return 0.56
		}
	}

	var localizedName: String {
		switch self {
		case .low: return String(localized: "sensitivity_low", defaultValue: "Low")
		case .normal: return String(localized: "sensitivity_normal", defaultValue: "Normal")
		case .high: return String(localized: "sensitivity_high", defaultValue: "High")
		}
	}

	var localizedDescription: String {
		switch self {
		case .low: return String(localized: "sensitivity_low_desc", defaultValue: "Less likely to wake early")
		case .normal: return String(localized: "sensitivity_normal_desc", defaultValue: "Balanced wake detection")
		case .high: return String(localized: "sensitivity_high_desc", defaultValue: "More likely to wake early")
		}
	}
}
