import SwiftUI

@main
struct TooLongApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(appDelegate.model)
        } label: {
            Label("Too Long", systemImage: appDelegate.model.phase.isWorking ? "waveform" : "text.bubble.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appDelegate.model)
        }
    }
}
