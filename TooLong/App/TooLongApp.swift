import SwiftUI

@main
struct TooLongApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(model)
                .preferredColorScheme(model.settings.forceDarkMode ? .dark : nil)
        } label: {
            Label("Too Long", systemImage: model.phase.isWorking ? "waveform" : "text.bubble.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
