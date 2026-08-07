import SwiftUI
import WatchKit

@main
struct WakeTFappApp: App {
	@WKApplicationDelegateAdaptor(WatchAppDelegate.self) var appDelegate

	var body: some Scene {
		WindowGroup {
			ContentView()
				.environmentObject(appDelegate.coordinator)
		}
	}
}
