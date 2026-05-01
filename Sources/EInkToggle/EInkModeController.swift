import AppKit
import ApplicationServices
import Darwin
import Foundation
import ObjectiveC.runtime
import ServiceManagement

@MainActor
final class EInkModeController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isApplying = false

    @Published private(set) var isNightShiftEnabled = false
    @Published private(set) var isNightShiftApplying = false

    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var isUpdatingLaunchAtLogin = false

    private let colorFilterSuiteName = "com.apple.mediaaccessibility"
    private let colorFilterEnabledKey = "__Color__-MADisplayFilterCategoryEnabled"
    private let lastKnownNightShiftKey = "lastKnownNightShiftEnabled"

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        isApplying = true

        Task { @MainActor in
            defer {
                isApplying = false
                refreshEInkState()
            }

            do {
                if SystemSettingsAutomation.hasAccessibilityTrust == false {
                    let shouldPrompt = presentAccessibilityExplainer()
                    guard shouldPrompt else {
                        isEnabled = false
                        return
                    }

                    SystemSettingsAutomation.requestAccessibilityTrustPrompt()
                    isEnabled = false
                    return
                }

                try SystemSettingsAutomation().setGrayscaleEnabled(enabled)
            } catch {
                presentAlert(
                    title: "Couldn't change grayscale",
                    message: error.localizedDescription
                )
            }
        }
    }

    func setNightShiftEnabled(_ enabled: Bool) {
        isNightShiftEnabled = enabled
        isNightShiftApplying = true

        Task { @MainActor in
            defer {
                isNightShiftApplying = false
                refreshNightShiftState()
            }

            do {
                try NightShiftBridge.setEnabled(enabled)
                UserDefaults.standard.set(enabled, forKey: lastKnownNightShiftKey)
            } catch {
                presentAlert(
                    title: "Couldn't change Night Shift",
                    message: error.localizedDescription
                )
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        isUpdatingLaunchAtLogin = true

        Task { @MainActor in
            defer {
                isUpdatingLaunchAtLogin = false
                refreshLaunchAtLoginState()
            }

            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                    UserDefaults.standard.removeObject(forKey: "hasShownLaunchAtLoginApprovalAlert")
                }
            } catch {
                presentAlert(
                    title: "Couldn't change launch at login",
                    message: error.localizedDescription
                )
            }
        }
    }

    func refresh() {
        refreshEInkState()
        refreshNightShiftState()
        refreshLaunchAtLoginState()
    }

    private func refreshEInkState() {
        if currentColorFilterEnabled() {
            isEnabled = true
        } else {
            isEnabled = false
        }
    }

    private func refreshNightShiftState() {
        if let storedValue = UserDefaults.standard.object(forKey: lastKnownNightShiftKey) as? Bool {
            isNightShiftEnabled = storedValue
        } else {
            isNightShiftEnabled = false
        }
    }

    private func refreshLaunchAtLoginState() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginEnabled = true
        case .requiresApproval:
            launchAtLoginEnabled = true
            presentLaunchAtLoginApprovalAlert()
        default:
            launchAtLoginEnabled = false
        }
    }

    private func currentColorFilterEnabled() -> Bool {
        if let value = CFPreferencesCopyValue(
            colorFilterEnabledKey as CFString,
            colorFilterSuiteName as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) as? Bool {
            return value
        }

        return false
    }

    private func presentAccessibilityExplainer() -> Bool {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.icon = AppIconProvider.appIconImage
        alert.messageText = "Accessibility permission is needed"
        alert.informativeText = "Grey controls the real Color Filters switch in System Settings, so macOS requires Accessibility access. After you continue, macOS will show its own permission prompt."
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentLaunchAtLoginApprovalAlert() {
        guard UserDefaults.standard.bool(forKey: "hasShownLaunchAtLoginApprovalAlert") == false else {
            return
        }

        UserDefaults.standard.set(true, forKey: "hasShownLaunchAtLoginApprovalAlert")
        presentAlert(
            title: "Finish enabling launch at login",
            message: "Approve Grey in System Settings > General > Login Items to finish turning this on."
        )
    }

    private func presentAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.icon = AppIconProvider.appIconImage
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private struct SystemSettingsAutomation {
    private let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Display")!
    private let settingsBundleID = "com.apple.systempreferences"
    private let colorFilterTypeSuite = "com.apple.mediaaccessibility"
    private let colorFilterTypeKey = "__Color__-MADisplayFilterType"

    static var hasAccessibilityTrust: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityTrustPrompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func setGrayscaleEnabled(_ enabled: Bool) throws {
        let settingsWasRunning = NSRunningApplication.runningApplications(withBundleIdentifier: settingsBundleID).isEmpty == false

        guard Self.hasAccessibilityTrust else {
            throw NSError(
                domain: "EInkToggle",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Grant Accessibility access to EInkToggle, then try again."
                ]
            )
        }

        if enabled {
            set(integer: 1, forSuite: colorFilterTypeSuite, key: colorFilterTypeKey)
        }

        NSWorkspace.shared.open(settingsURL)
        Thread.sleep(forTimeInterval: 1.2)

        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: settingsBundleID).first else {
            throw NSError(domain: "EInkToggle", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not open System Settings."
            ])
        }

        app.activate()
        Thread.sleep(forTimeInterval: 0.8)

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = firstWindow(of: axApp) else {
            throw NSError(domain: "EInkToggle", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Could not access the Display settings window."
            ])
        }

        try setSwitch(afterAnyOf: ["Increase contrast"], to: false, in: window)
        try setSwitch(afterAnyOf: ["Differentiate without colour", "Differentiate without color"], to: false, in: window)
        try setSwitch(afterAnyOf: ["Colour filters", "Color Filters", "Color filters"], to: enabled, in: window)

        if settingsWasRunning == false {
            Thread.sleep(forTimeInterval: 0.3)
            _ = app.terminate()
        }
    }

    private func firstWindow(of app: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        guard error == .success else { return nil }
        let windows = value as? [AXUIElement]
        return windows?.first
    }

    private func setSwitch(afterAnyOf labels: [String], to enabled: Bool, in root: AXUIElement) throws {
        let normalizedLabels = Set(labels.map(normalize))
        guard let checkbox = checkbox(afterAnyMatching: normalizedLabels, in: root) else {
            throw NSError(domain: "EInkToggle", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Could not find \(labels[0]) in System Settings."
            ])
        }

        let current = (anyAttr(checkbox, kAXValueAttribute as String) as? NSNumber)?.intValue ?? 0
        let desired = enabled ? 1 : 0

        if current != desired {
            let result = AXUIElementPerformAction(checkbox, kAXPressAction as CFString)
            guard result == .success else {
                throw NSError(domain: "EInkToggle", code: Int(result.rawValue), userInfo: [
                    NSLocalizedDescriptionKey: "Could not change \(labels[0])."
                ])
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
    }

    private func checkbox(afterAnyMatching labels: Set<String>, in root: AXUIElement) -> AXUIElement? {
        let nodes = flatten(root)

        for (index, node) in nodes.enumerated() {
            let role = (attr(node, kAXRoleAttribute as String) as String?) ?? ""
            guard role == kAXStaticTextRole as String else { continue }

            if let text = stringValue(node), labels.contains(normalize(text)) {
                for next in nodes.dropFirst(index + 1) {
                    let nextRole = (attr(next, kAXRoleAttribute as String) as String?) ?? ""
                    if nextRole == kAXCheckBoxRole as String {
                        return next
                    }
                    if nextRole == kAXStaticTextRole as String {
                        break
                    }
                }
            }
        }

        return nil
    }

    private func flatten(_ element: AXUIElement) -> [AXUIElement] {
        [element] + children(of: element).flatMap(flatten)
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        attr(element, kAXChildrenAttribute as String) ?? []
    }

    private func stringValue(_ element: AXUIElement) -> String? {
        if let title: String = attr(element, kAXTitleAttribute as String), !title.isEmpty {
            return title
        }
        if let value: String = attr(element, kAXValueAttribute as String), !value.isEmpty {
            return value
        }
        if let description: String = attr(element, kAXDescriptionAttribute as String), !description.isEmpty {
            return description
        }
        return nil
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func attr<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard error == .success else { return nil }
        return value as? T
    }

    private func anyAttr(_ element: AXUIElement, _ name: String) -> Any? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard error == .success else { return nil }
        return value
    }

    private func set(integer: Int, forSuite suiteName: String, key: String) {
        CFPreferencesSetValue(
            key as CFString,
            integer as CFPropertyList,
            suiteName as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSynchronize(
            suiteName as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }
}

private enum NightShiftBridge {
    private static let displayControlsPath = "/System/Library/CoreServices/ControlCenter.app/Contents/PlugIns/DisplayControls.appex/Contents/MacOS/DisplayControls"

    typealias AllocFunc = @convention(c) (AnyClass, Selector) -> AnyObject
    typealias InitFunc = @convention(c) (AnyObject, Selector) -> AnyObject?
    typealias ObjReturnFunc = @convention(c) (AnyObject, Selector) -> AnyObject?
    typealias BoolFunc = @convention(c) (AnyObject, Selector, Bool) -> Bool

    static func setEnabled(_ enabled: Bool) throws {
        let blueLightClient = try makeBlueLightClient()

        let setActiveSelector = sel_registerName("setActive:")
        let setEnabledSelector = sel_registerName("setEnabled:")

        guard let setActiveImplementation = class_getMethodImplementation(type(of: blueLightClient), setActiveSelector),
              let setEnabledImplementation = class_getMethodImplementation(type(of: blueLightClient), setEnabledSelector) else {
            throw NSError(domain: "EInkToggle", code: 20, userInfo: [
                NSLocalizedDescriptionKey: "Night Shift controls are unavailable on this macOS version."
            ])
        }

        let setActive = unsafeBitCast(setActiveImplementation, to: BoolFunc.self)
        let setNightShift = unsafeBitCast(setEnabledImplementation, to: BoolFunc.self)

        guard setActive(blueLightClient, setActiveSelector, true) else {
            throw NSError(domain: "EInkToggle", code: 21, userInfo: [
                NSLocalizedDescriptionKey: "Could not activate the Night Shift client."
            ])
        }

        guard setNightShift(blueLightClient, setEnabledSelector, enabled) else {
            throw NSError(domain: "EInkToggle", code: 22, userInfo: [
                NSLocalizedDescriptionKey: "Could not change Night Shift."
            ])
        }
    }

    private static func makeBlueLightClient() throws -> AnyObject {
        guard dlopen(displayControlsPath, RTLD_NOW) != nil else {
            let message = dlerror().map { String(cString: $0) } ?? "Could not load DisplayControls."
            throw NSError(domain: "EInkToggle", code: 23, userInfo: [
                NSLocalizedDescriptionKey: message
            ])
        }

        guard let cbClientClass: AnyClass = NSClassFromString("CBClient") else {
            throw NSError(domain: "EInkToggle", code: 24, userInfo: [
                NSLocalizedDescriptionKey: "Night Shift controls are unavailable on this Mac."
            ])
        }

        let allocSelector = sel_registerName("alloc")
        let initSelector = sel_registerName("init")
        let blueLightSelector = sel_registerName("blueLightClient")

        guard let allocImplementation = class_getMethodImplementation(object_getClass(cbClientClass), allocSelector),
              let initImplementation = class_getMethodImplementation(cbClientClass, initSelector),
              let blueLightImplementation = class_getMethodImplementation(cbClientClass, blueLightSelector) else {
            throw NSError(domain: "EInkToggle", code: 25, userInfo: [
                NSLocalizedDescriptionKey: "Night Shift controls are unavailable on this macOS version."
            ])
        }

        let allocate = unsafeBitCast(allocImplementation, to: AllocFunc.self)
        let initialize = unsafeBitCast(initImplementation, to: InitFunc.self)
        let blueLightClient = unsafeBitCast(blueLightImplementation, to: ObjReturnFunc.self)

        let allocatedClient = allocate(cbClientClass, allocSelector)

        guard let client = initialize(allocatedClient, initSelector),
              let clientBlueLight = blueLightClient(client, blueLightSelector) else {
            throw NSError(domain: "EInkToggle", code: 26, userInfo: [
                NSLocalizedDescriptionKey: "Could not create the Night Shift client."
            ])
        }

        return clientBlueLight
    }
}
