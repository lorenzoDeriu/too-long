import AppKit
import Foundation

/// Watches a user-chosen folder and reports newly saved audio/video files, so a voice note
/// saved from an app like WhatsApp or Telegram Desktop can be picked up without dragging it
/// into Too Long by hand.
@MainActor
final class AutoImportService {
    var onNewFile: ((URL) -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private var accessedURL: URL?
    private var knownFileNames: Set<String> = []
    private var pendingScan: DispatchWorkItem?

    /// Lets the user pick a folder and returns a security-scoped bookmark for it, or `nil`
    /// if they cancelled. The bookmark is what makes the choice survive app relaunches.
    func pickFolder() -> (url: URL, bookmark: Data)? {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Watch a folder"
        panel.prompt = "Watch Folder"
        panel.message = "Too Long will import new voice notes saved to this folder automatically."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return nil }

        return (url, bookmark)
    }

    /// Resolves a stored bookmark and starts watching it. `refreshedBookmark` is called when
    /// the bookmark needed to be renewed (e.g. the folder moved), so the caller can persist it.
    /// Returns `false` if the bookmark could no longer be resolved.
    @discardableResult
    func startWatching(bookmark: Data, refreshedBookmark: (Data) -> Void) -> Bool {
        stopWatching()

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return false }

        if isStale, let refreshed = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            refreshedBookmark(refreshed)
        }

        guard url.startAccessingSecurityScopedResource() else { return false }

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            url.stopAccessingSecurityScopedResource()
            return false
        }

        accessedURL = url
        knownFileNames = Self.audioFileNames(in: url)

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write],
            queue: .main
        )
        newSource.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.scheduleScan()
            }
        }
        newSource.setCancelHandler {
            close(fd)
        }
        newSource.resume()
        source = newSource
        return true
    }

    func stopWatching() {
        pendingScan?.cancel()
        pendingScan = nil
        source?.cancel()
        source = nil
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
        knownFileNames = []
    }

    /// Debounces bursts of directory-write events (e.g. a file being written and then renamed)
    /// into a single rescan.
    private func scheduleScan() {
        pendingScan?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.scanForNewFiles() }
        pendingScan = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }

    private func scanForNewFiles() {
        guard let accessedURL else { return }
        let currentNames = Self.audioFileNames(in: accessedURL)
        let newNames = currentNames.subtracting(knownFileNames)
        knownFileNames = currentNames
        guard !newNames.isEmpty else { return }

        for name in newNames.sorted() {
            onNewFile?(accessedURL.appending(path: name))
        }
    }
}

extension AutoImportService {
    nonisolated static let supportedExtensions: Set<String> = [
        "opus", "ogg", "m4a", "mp3", "wav", "aac", "caf", "aiff", "aif", "amr", "flac", "mp4", "mov", "m4v",
    ]

    nonisolated static func audioFileNames(in url: URL) -> Set<String> {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return Set(
            items
                .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
                .map(\.lastPathComponent)
        )
    }
}
