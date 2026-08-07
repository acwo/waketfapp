import WatchKit

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
	let coordinator = AlarmCoordinator()

	func applicationDidFinishLaunching() {}

	func handle(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
		Task { @MainActor in
			coordinator.handleResumedSession(extendedRuntimeSession)
		}
	}
}
