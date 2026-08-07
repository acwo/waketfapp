import Foundation

enum AlarmStatus: String, Codable, Sendable {
	case disarmed
	case scheduling
	case armed
	case monitoring
	case alerting
	case completed
	case failed
}
