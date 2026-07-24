import AppKit
import SwiftUI

@main
struct TooLongApp: App {
    @State private var model = AppModel()

    private static let menuBarLogo: NSImage = {
        guard
            let source = NSImage(named: "LogoMark"),
            let logo = source.copy() as? NSImage
        else {
            return NSImage()
        }

        logo.size = NSSize(width: 18, height: 18)
        logo.isTemplate = true
        return logo
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(model)
        } label: {
            Image(nsImage: Self.menuBarLogo)
                .interpolation(.high)
                .accessibilityLabel("Too Long")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
