# A taste of Gray

`A taste of Gray` is a lightweight macOS menu bar app for making a screen feel a little more e-ink friendly.

The Swift package and executable are named `ATasteOfGray`. The user-facing app name in macOS is `A taste of Gray`.

## What it does

- Toggles the real **Color Filters > Grayscale** switch in System Settings
- Toggles **Night Shift** from the menu bar
- Lets you enable **Launch at login**
- Lives as an **LSUIElement** menu bar app, so it runs without a Dock icon

This project is intentionally narrow. It focuses on the controls that can be switched reliably enough from a small utility instead of trying to own every display setting.

## How it works

Grayscale is changed by automating the Display section of macOS Accessibility settings. Because that touches real System Settings UI, the app needs Accessibility permission.

Night Shift is handled through a small Objective-C runtime bridge that loads `CoreBrightness.framework` and drives `CBBlueLightClient` directly. That class has backed Night Shift since macOS 10.12.4, so the path is reasonably stable, but it is still a private API and not officially supported by Apple.

## Requirements

- macOS 13 or newer
- Xcode 15+ or recent Command Line Tools with Swift support

## Run locally

```bash
swift run ATasteOfGray
```

The first time you try to toggle grayscale, macOS will ask for Accessibility access. Grant it, then retry from the menu bar app.

## Build an app bundle

```bash
./scripts/make-app.sh
```

That script:

- builds a release binary
- generates an `.icns` app icon
- creates a standalone app bundle at `dist/A taste of Gray.app`

You can then launch the app bundle directly like a normal menu bar app.

## Open in Xcode

Open [Package.swift](Package.swift) in Xcode. Xcode treats the package like a project, so you can build and run it as a standard macOS app target.

## Permissions and caveats

- **Accessibility access is required** for the grayscale toggle because the app drives the real System Settings control.
- **Launch at login may need a second approval step** in `System Settings > General > Login Items`.
- **Night Shift state is not read back from the system.** The menu currently reflects the last value requested by the app, stored in `UserDefaults`.
- **Night Shift support is more brittle than grayscale.** It depends on private macOS internals and could break on a future OS update.
- **Other display tweaks remain manual.** Contrast, brightness, True Tone, and similar controls are not managed here.

## Project layout

- [Sources/ATasteOfGray/ATasteOfGrayApp.swift](Sources/ATasteOfGray/ATasteOfGrayApp.swift): app entry point and menu bar setup
- [Sources/ATasteOfGray/MenuBarContent.swift](Sources/ATasteOfGray/MenuBarContent.swift): menu UI
- [Sources/ATasteOfGray/EInkModeController.swift](Sources/ATasteOfGray/EInkModeController.swift): grayscale, Night Shift, and launch-at-login control logic
- [scripts/make-app.sh](scripts/make-app.sh): release app bundle builder
- [scripts/generate-icon.swift](scripts/generate-icon.swift): app icon generator
