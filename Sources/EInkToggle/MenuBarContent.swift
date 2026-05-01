import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var controller: EInkModeController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toggleRow(
                "Grayscale",
                isOn: Binding(
                    get: { controller.isEnabled },
                    set: { controller.setEnabled($0) }
                ),
                disabled: controller.isApplying
            )

            toggleRow(
                "Night Shift",
                isOn: Binding(
                    get: { controller.isNightShiftEnabled },
                    set: { controller.setNightShiftEnabled($0) }
                ),
                disabled: controller.isNightShiftApplying
            )

            toggleRow(
                "Launch at login",
                isOn: Binding(
                    get: { controller.launchAtLoginEnabled },
                    set: { controller.setLaunchAtLogin($0) }
                ),
                disabled: controller.isUpdatingLaunchAtLogin
            )

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

    @ViewBuilder
    private func toggleRow(_ title: String, isOn: Binding<Bool>, disabled: Bool) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(disabled)
        }
    }
}
