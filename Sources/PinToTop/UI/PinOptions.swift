import SwiftUI

/// The two app-wide switches, shown in both the menu bar picker and the main window.
struct PinOptions: View {
    @ObservedObject var model: MirrorModel

    var body: some View {
        HStack(spacing: 16) {
            Toggle(isOn: $model.showOnAllDisplays) {
                Label("Show on all displays", systemImage: "rectangle.on.rectangle")
            }
            .help("On: a copy on every connected display. Off: one panel you can drag to any display.")

            Toggle(isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            )) {
                Label("Launch at login", systemImage: "power.circle")
            }
            .help("Start Pin To Top in the menu bar when you log in.")

            Spacer(minLength: 0)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .onAppear { model.refreshLaunchAtLogin() }
    }
}
