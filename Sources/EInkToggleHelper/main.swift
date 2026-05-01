import AppKit
import Darwin
import Foundation
import Intents

enum HelperError: Error {
    case invalidArguments
    case missingSystemClasses
}

enum ShortcutIntent {
    case colorFilters
    case contrast

    var intentClassName: String {
        switch self {
        case .colorFilters:
            return "UAToggleColorFiltersIntent"
        case .contrast:
            return "UAToggleContrastIntent"
        }
    }
}

let shortcutBundlePath = "/System/Library/PrivateFrameworks/UniversalAccess.framework/PlugIns/UASettingsShortcuts.appex/Contents/MacOS/UASettingsShortcuts"

func main() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 1, let enabled = parseEnabled(arguments[0]) else {
        throw HelperError.invalidArguments
    }

    dlopen(shortcutBundlePath, RTLD_NOW)

    if enabled {
        set(integer: 1, forSuite: "com.apple.mediaaccessibility", key: "__Color__-MADisplayFilterType")
    }

    set(value: enabled, forSuite: "com.apple.mediaaccessibility", key: "__Color__-MADisplayFilterCategoryEnabled")
    set(value: enabled, forSuite: "com.apple.Accessibility", key: "DifferentiateWithoutColor")

    try applySystemIntent(.colorFilters, enabled: enabled)
    try applySystemIntent(.contrast, enabled: enabled)
}

func parseEnabled(_ value: String) -> Bool? {
    switch value.lowercased() {
    case "on", "true", "1":
        return true
    case "off", "false", "0":
        return false
    default:
        return nil
    }
}

func set(value: Bool, forSuite suiteName: String, key: String) {
    CFPreferencesSetValue(
        key as CFString,
        value ? kCFBooleanTrue : kCFBooleanFalse,
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

func set(integer: Int, forSuite suiteName: String, key: String) {
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

func applySystemIntent(_ shortcutIntent: ShortcutIntent, enabled: Bool) throws {
    guard
        let intentClass = NSClassFromString(shortcutIntent.intentClassName) as? NSObject.Type,
        let rootHandlerClass = NSClassFromString("UAIntentHandler") as? NSObject.Type
    else {
        throw HelperError.missingSystemClasses
    }

    let intent = intentClass.init()
    let operationTurn = 1
    let stateOn = 1
    let stateOff = 2

    intent.setValue(operationTurn, forKey: "operation")
    intent.setValue(enabled ? stateOn : stateOff, forKey: "state")

    let rootHandler = rootHandlerClass.init()
    let handlerSelector = NSSelectorFromString("handlerForIntent:")
    typealias HandlerFunction = @convention(c) (AnyObject, Selector, AnyObject) -> AnyObject
    let handler = unsafeBitCast(
        rootHandler.method(for: handlerSelector),
        to: HandlerFunction.self
    )(rootHandler, handlerSelector, intent)

    let applySelector = NSSelectorFromString("_handleIntent:operation:state:returningResultingState:")
    typealias ApplyFunction = @convention(c) (
        AnyObject,
        Selector,
        AnyObject,
        Int,
        Int,
        UnsafeMutablePointer<ObjCBool>
    ) -> Bool
    var resultingState = ObjCBool(false)
    _ = unsafeBitCast(
        handler.method(for: applySelector),
        to: ApplyFunction.self
    )(
        handler,
        applySelector,
        intent,
        operationTurn,
        enabled ? stateOn : stateOff,
        &resultingState
    )
}

do {
    try main()
} catch HelperError.invalidArguments {
    fputs("usage: EInkToggleHelper <on|off>\n", stderr)
    exit(2)
} catch {
    fputs("helper failed: \(error)\n", stderr)
    exit(1)
}
