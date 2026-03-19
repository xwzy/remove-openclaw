import SwiftUI
import AppKit

final class RemoveOpenClawAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard OpenClawCLIRunner.shouldRunCLI() else { return }

        NSApp.setActivationPolicy(.prohibited)
        Task { @MainActor in
            let exitCode = await OpenClawCLIRunner().run()
            fflush(stdout)
            fflush(stderr)
            exit(exitCode)
        }
    }
}

@main
struct remove_openclawApp: App {
    @NSApplicationDelegateAdaptor(RemoveOpenClawAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup {
            if OpenClawCLIRunner.shouldRunCLI() {
                EmptyView()
            } else {
                ContentView()
            }
        }
    }
}
