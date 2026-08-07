import Foundation
import WatchKit

protocol ExtendedRuntimeDelegate: AnyObject, Sendable {
	func runtimeSessionDidStart()
	func runtimeSessionWillExpire()
	func runtimeSessionDidInvalidate(reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?)
}

final class ExtendedRuntimeController: NSObject, @unchecked Sendable {
	private(set) var session: WKExtendedRuntimeSession?
	private(set) var isSessionActive: Bool = false
	private(set) var expirationDate: Date?
	weak var delegate: ExtendedRuntimeDelegate?

	var hasActiveSession: Bool {
		session != nil && isSessionActive
	}

	func scheduleSession(startDate: Date) -> Bool {
		guard session == nil else { return false }

		let newSession = WKExtendedRuntimeSession()
		newSession.delegate = self
		session = newSession
		newSession.start(at: startDate)
		return true
	}

	func attachResumedSession(_ resumedSession: WKExtendedRuntimeSession) {
		session = resumedSession
		resumedSession.delegate = self

		if resumedSession.state == .running {
			isSessionActive = true
			expirationDate = resumedSession.expirationDate
			delegate?.runtimeSessionDidStart()
		}
	}

	func invalidateSession() {
		guard let session else { return }
		session.invalidate()
	}

	func triggerAlarm(hapticType: WKHapticType = .notification) {
		guard let session, session.state == .running else { return }
		session.notifyUser(hapticType: hapticType) { _ in
			return 3.0
		}
	}

	func releaseSession() {
		session = nil
		isSessionActive = false
		expirationDate = nil
	}
}

extension ExtendedRuntimeController: WKExtendedRuntimeSessionDelegate {
	func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
		isSessionActive = true
		expirationDate = extendedRuntimeSession.expirationDate
		delegate?.runtimeSessionDidStart()
	}

	func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
		delegate?.runtimeSessionWillExpire()
	}

	func extendedRuntimeSession(
		_ extendedRuntimeSession: WKExtendedRuntimeSession,
		didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
		error: Error?
	) {
		isSessionActive = false
		expirationDate = nil
		delegate?.runtimeSessionDidInvalidate(reason: reason, error: error)
	}
}
