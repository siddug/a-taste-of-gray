import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class EInkModeController: ObservableObject {
    struct ManagedSetting {
        let suiteName: String
        let key: String
        let displayName: String
    }

    enum SettingsDestination {
        case accessibilityDisplay
        case display

        var url: URL? {
            switch self {
            case .accessibilityDisplay:
                return URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Display")
            case .display:
                return URL(string: "x-apple.systempreferences:com.apple.preference.displays")
            }
        }
    }

    @Published private(set) var isEnabled = false
    @Published private(set) var isApplying = false
    @Published private(set) var statusMessage = "Turn on e-ink mode to enable the core accessibility settings."

    let managedSettings: [ManagedSetting] = [
        ManagedSetting(
            suiteName: "com.apple.mediaaccessibility",
            key: "__Color__-MADisplayFilterCategoryEnabled",
            displayName: "Color Filters (Grayscale)"
        ),
    ]

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        isApplying = true
        statusMessage = enabled ? "Applying e-ink mode..." : "Turning e-ink mode off..."

        Task { @MainActor in
            defer {
                isApplying = false
                refresh()
            }

            do {
                try SystemSettingsAutomation().setEnabled(enabled)
                statusMessage = enabled
                    ? "Grayscale is on. Use Display settings for Night Shift, True Tone, and brightness."
                    : "Grayscale is off."
            } catch {
                statusMessage = "Toggle failed: \(error.localizedDescription)"
            }
        }
    }

    func refresh() {
        let values = [
            currentColorFilterEnabled(),
        ]

        if values.allSatisfy({ $0 }) {
            isEnabled = true
            statusMessage = "Grayscale is on. Use Display settings for Night Shift, True Tone, and brightness."
        } else if values.contains(true) {
            isEnabled = false
            statusMessage = "Grayscale looks partially on. Toggling will normalize it."
        } else {
            isEnabled = false
            statusMessage = "Turn on grayscale mode."
        }
    }

    func open(_ destination: SettingsDestination) {
        if let url = destination.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func currentValue(for setting: ManagedSetting) -> Bool {
        if let value = CFPreferencesCopyValue(
            setting.key as CFString,
            setting.suiteName as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) as? Bool {
            return value
        }

        return false
    }

    private func currentColorFilterEnabled() -> Bool {
        currentValue(for: managedSettings[0])
    }

}

private struct SystemSettingsAutomation {
    private let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Display")!
    private let settingsBundleID = "com.apple.systempreferences"
    private let colorFilterTypeSuite = "com.apple.mediaaccessibility"
    private let colorFilterTypeKey = "__Color__-MADisplayFilterType"

    func setEnabled(_ enabled: Bool) throws {
        guard ensureAccessibilityTrust() else {
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

        // Keep the effect intentionally lightweight: grayscale only.
        try setSwitch(afterAnyOf: ["Increase contrast"], to: false, in: window)
        try setSwitch(afterAnyOf: ["Differentiate without colour", "Differentiate without color"], to: false, in: window)
        try setSwitch(afterAnyOf: ["Colour filters", "Color Filters", "Color filters"], to: enabled, in: window)
    }

    private func ensureAccessibilityTrust() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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
