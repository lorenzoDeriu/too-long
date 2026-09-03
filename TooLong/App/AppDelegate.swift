import AppKit

/// Receives the "open document" Apple Event macOS sends when a file is opened via
/// Finder's Open With, dropped on the Dock icon, or double-clicked once Too Long is
/// the default handler. Owns the shared `AppModel` so the file can be handed straight
/// to transcription.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        NSApp.activate(ignoringOtherApps: true)
        model.process(fileURL: url)
    }
}
