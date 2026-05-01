import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var controller: EInkModeController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("E-Ink Mode")
                .font(.headline)

            Toggle(
                "Enable e-ink mode",
                isOn: Binding(
                    get: { controller.isEnabled },
                    set: { controller.setEnabled($0) }
                )
            )
            .toggleStyle(.switch)
            .disabled(controller.isApplying)

            Text(controller.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("This toggle manages:")
                    .font(.subheadline.weight(.semibold))

                ForEach(controller.managedSettings, id: \.key) { setting in
                    Label(setting.displayName, systemImage: "checkmark.circle")
                        .font(.caption)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Manual follow-up")
                    .font(.subheadline.weight(.semibold))

                Text("This app now only toggles grayscale. Night Shift, True Tone, and brightness still need to be adjusted in macOS Display settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Open Accessibility Display") {
                    controller.open(.accessibilityDisplay)
                }

                Button("Open Display Settings") {
                    controller.open(.display)
                }
            }

            Divider()

            HStack {
                Button("Refresh") {
                    controller.refresh()
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
    }
}
