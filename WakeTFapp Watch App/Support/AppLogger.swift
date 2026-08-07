import os

enum AppLogger {
	static let alarm = Logger(subsystem: "com.waketfapp", category: "alarm")
	static let motion = Logger(subsystem: "com.waketfapp", category: "motion")
	static let heartRate = Logger(subsystem: "com.waketfapp", category: "heartrate")
	static let runtime = Logger(subsystem: "com.waketfapp", category: "runtime")
	static let scoring = Logger(subsystem: "com.waketfapp", category: "scoring")
}
