import AppKit
import SwiftUI

@main
struct EInkToggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = EInkModeController()

    var body: some Scene {
        MenuBarExtra("E-Ink Toggle", systemImage: controller.isEnabled ? "circle.lefthalf.filled" : "circle") {
            MenuBarContent(controller: controller)
                .frame(width: 320)
                .onAppear {
                    controller.refresh()
                }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
