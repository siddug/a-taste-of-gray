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
        NSApp.applicationIconImage = AppIconProvider.appIconImage

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.showMenuBarHintIfNeeded()
        }
    }

    @MainActor
    private func showMenuBarHintIfNeeded() {
        let defaults = UserDefaults.standard
        let key = "hasShownMenuBarHint"

        guard defaults.bool(forKey: key) == false else {
            return
        }

        defaults.set(true, forKey: key)

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.icon = AppIconProvider.appIconImage
        alert.messageText = "EInkToggle lives in your menu bar"
        alert.informativeText = "Look for the half-filled circle near the clock. That menu is where you turn grayscale on or off."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

enum AppIconProvider {
    static var appIconImage: NSImage {
        let side: CGFloat = 256
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: image.size)
        NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 56, yRadius: 56).fill()

        let borderRect = rect.insetBy(dx: 6, dy: 6)
        NSColor(calibratedWhite: 0.82, alpha: 1).setStroke()
        let border = NSBezierPath(roundedRect: borderRect, xRadius: 52, yRadius: 52)
        border.lineWidth = 6
        border.stroke()

        let configuration = NSImage.SymbolConfiguration(pointSize: 128, weight: .regular)
        let symbol = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)

        NSColor.black.set()
        symbol?.draw(in: NSRect(x: 54, y: 54, width: 148, height: 148))

        image.unlockFocus()
        return image
    }
}
