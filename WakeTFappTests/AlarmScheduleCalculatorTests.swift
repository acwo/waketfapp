import XCTest
@testable import WakeTFapp_Watch_App

final class AlarmScheduleCalculatorTests: XCTestCase {
	private var calculator: AlarmScheduleCalculator!
	private var calendar: Calendar!

	override func setUp() {
		super.setUp()
		calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
		calculator = AlarmScheduleCalculator(calendar: calendar)
	}

	func testSameDayFutureInterval() {
		let now = makeDate(year: 2025, month: 6, day: 15, hour: 20, minute: 0)
		let calc = AlarmScheduleCalculator(calendar: calendar)

		let window = calc.resolveNextOccurrence(
			earliestHour: 7, earliestMinute: 0,
			latestHour: 7, latestMinute: 30,
			from: now
		)

		XCTAssertNotNil(window)
		XCTAssertEqual(window!.durationMinutes, 30)

		let earliestComponents = calendar.dateComponents([.hour, .minute, .day], from: window!.earliest)
		XCTAssertEqual(earliestComponents.hour, 7)
		XCTAssertEqual(earliestComponents.minute, 0)
		XCTAssertEqual(earliestComponents.day, 16)
	}

	func testAlreadyPassedMovesToTomorrow() {
		let now = makeDate(year: 2025, month: 6, day: 15, hour: 8, minute: 0)

		let window = calculator.resolveNextOccurrence(
			earliestHour: 7, earliestMinute: 0,
			latestHour: 7, latestMinute: 30,
			from: now
		)

		XCTAssertNotNil(window)
		let day = calendar.component(.day, from: window!.earliest)
		XCTAssertEqual(day, 16)
	}

	func testIntervalCrossingMidnight() {
		let now = makeDate(year: 2025, month: 6, day: 15, hour: 22, minute: 0)

		let window = calculator.resolveNextOccurrence(
			earliestHour: 23, earliestMinute: 50,
			latestHour: 0, latestMinute: 10,
			from: now
		)

		XCTAssertNotNil(window)
		XCTAssertEqual(window!.durationMinutes, 20)

		let earliestDay = calendar.component(.day, from: window!.earliest)
		let latestDay = calendar.component(.day, from: window!.latest)
		XCTAssertEqual(earliestDay, 15)
		XCTAssertEqual(latestDay, 16)
	}

	func testMinimumValidDuration() {
		let now = makeDate(year: 2025, month: 6, day: 15, hour: 6, minute: 0)

		let window = calculator.resolveNextOccurrence(
			earliestHour: 7, earliestMinute: 0,
			latestHour: 7, latestMinute: 5,
			from: now
		)

		XCTAssertNotNil(window)
		XCTAssertEqual(window!.durationMinutes, 5)
	}

	func testExact30MinuteDuration() {
		let now = makeDate(year: 2025, month: 6, day: 15, hour: 6, minute: 0)

		let window = calculator.resolveNextOccurrence(
			earliestHour: 7, earliestMinute: 0,
			latestHour: 7, latestMinute: 30,
			from: now
		)

		XCTAssertNotNil(window)
		XCTAssertEqual(window!.durationMinutes, 30)
	}

	func testRejection31Minutes() {
		let now = makeDate(year: 2025, month: 6, day: 15, hour: 6, minute: 0)

		let window = calculator.resolveNextOccurrence(
			earliestHour: 7, earliestMinute: 0,
			latestHour: 7, latestMinute: 31,
			from: now
		)

		XCTAssertNotNil(window)
		XCTAssertEqual(window!.durationMinutes, 31)

		let error = AlarmValidation.validate(
			earliest: window!.earliest,
			latest: window!.latest,
			now: now
		)
		XCTAssertNotNil(error)
		if case .windowTooLong(let mins) = error {
			XCTAssertEqual(mins, 31)
		} else {
			XCTFail("Expected windowTooLong error")
		}
	}

	func testRejection60MinuteWindow() {
		let now = makeDate(year: 2025, month: 6, day: 15, hour: 6, minute: 0)

		let window = calculator.resolveNextOccurrence(
			earliestHour: 9, earliestMinute: 0,
			latestHour: 10, latestMinute: 0,
			from: now
		)

		XCTAssertNotNil(window)
		XCTAssertEqual(window!.durationMinutes, 60)

		let error = AlarmValidation.validate(
			earliest: window!.earliest,
			latest: window!.latest,
			now: now
		)
		XCTAssertNotNil(error)
		if case .windowTooLong(let mins) = error {
			XCTAssertEqual(mins, 60)
		} else {
			XCTFail("Expected windowTooLong error")
		}
	}

	func testValidationEarliestInPast() {
		let now = Date()
		let earliest = now.addingTimeInterval(-10)
		let latest = earliest.addingTimeInterval(600)

		let error = AlarmValidation.validate(earliest: earliest, latest: latest, now: now)
		XCTAssertNotNil(error)
		if case .earliestInPast = error {} else {
			XCTFail("Expected earliestInPast error")
		}
	}

	func testValidationLatestBeforeEarliest() {
		let now = Date()
		let earliest = now.addingTimeInterval(300)
		let latest = earliest.addingTimeInterval(-100)

		let error = AlarmValidation.validate(earliest: earliest, latest: latest, now: now)
		XCTAssertNotNil(error)
		if case .latestBeforeEarliest = error {} else {
			XCTFail("Expected latestBeforeEarliest error")
		}
	}

	func testValidationAlreadyScheduled() {
		let now = Date()
		let earliest = now.addingTimeInterval(300)
		let latest = earliest.addingTimeInterval(600)

		let error = AlarmValidation.validate(
			earliest: earliest, latest: latest, now: now,
			hasExistingAlarm: true
		)
		XCTAssertNotNil(error)
		if case .alarmAlreadyScheduled = error {} else {
			XCTFail("Expected alarmAlreadyScheduled error")
		}
	}

	private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		components.hour = hour
		components.minute = minute
		components.second = 0
		return calendar.date(from: components)!
	}
}
