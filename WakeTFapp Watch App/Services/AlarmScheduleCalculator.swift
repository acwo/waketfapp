import Foundation

struct AlarmScheduleCalculator: Sendable {
	private let calendar: Calendar

	init(calendar: Calendar = .autoupdatingCurrent) {
		self.calendar = calendar
	}

	struct ResolvedWindow: Sendable, Equatable {
		let earliest: Date
		let latest: Date
		let durationMinutes: Int
	}

	func resolveNextOccurrence(
		earliestHour: Int,
		earliestMinute: Int,
		latestHour: Int,
		latestMinute: Int,
		from now: Date = Date()
	) -> ResolvedWindow? {
		let earliest = resolveNextTime(hour: earliestHour, minute: earliestMinute, from: now)
		var latest: Date

		let crossesMidnight = (latestHour < earliestHour) ||
			(latestHour == earliestHour && latestMinute <= earliestMinute)

		if crossesMidnight {
			latest = resolveNextTime(hour: latestHour, minute: latestMinute, from: earliest)
			if latest <= earliest {
				latest = calendar.date(byAdding: .day, value: 1, to: latest) ?? latest
			}
		} else {
			latest = calendar.date(
				bySettingHour: latestHour,
				minute: latestMinute,
				second: 0,
				of: earliest
			) ?? earliest
		}

		guard latest > earliest else { return nil }

		let durationMinutes = Int(latest.timeIntervalSince(earliest) / 60)
		return ResolvedWindow(earliest: earliest, latest: latest, durationMinutes: durationMinutes)
	}

	private func resolveNextTime(hour: Int, minute: Int, from referenceDate: Date) -> Date {
		var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
		components.hour = hour
		components.minute = minute
		components.second = 0

		guard let candidate = calendar.date(from: components) else {
			return referenceDate
		}

		if candidate > referenceDate {
			return candidate
		}

		return calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
	}
}
