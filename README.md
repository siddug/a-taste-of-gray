# EInkToggle

A tiny macOS menu bar app inspired by Blake Watson's e-ink-mode recipe. It gives you one toggle for grayscale and quick links for the rest of the workflow.

## What it toggles

- Grayscale

## What still needs a manual adjustment

- Contrast
- Differentiate without color
- Night Shift
- True Tone
- Brightness

The app now only flips the real Color Filters switch in System Settings and leaves the stronger contrast-related settings alone. The display-temperature and brightness controls do not have a stable public API, so the app opens the relevant System Settings pages instead of trying to fake those controls.

## Run it

```bash
swift run EInkToggle
```

## Make an app bundle

```bash
./scripts/make-app.sh
```

That produces `dist/EInkToggle.app`, which you can launch like a regular menu bar app.

## Open it in Xcode

Open `Package.swift` in Xcode. Xcode treats the package like a project, so you can run it as a normal macOS app from there.
