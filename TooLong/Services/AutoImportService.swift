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

    /// Files seen for the first time but not yet confirmed stable, keyed by name, with the
    /// size/modification-date snapshot taken the last time they were checked.
    private var pendingFiles: [String: FileSnapshot] = [:]
    /// Keeps re-checking `pendingFiles` for stability even when no further directory-write
    /// events arrive (a file being copied or downloaded into the folder only triggers a
    /// directory event when its entry first appears, not while its contents keep growing).
    private var stabilityRecheck: DispatchWorkItem?

    private struct FileSnapshot: Equatable {
        let size: Int
        let modificationDate: Date?
    }

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
        stabilityRecheck?.cancel()
        stabilityRecheck = nil
        pendingFiles = [:]
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

    /// Looks for files that are new since the last scan, and reports the ones that have
    /// stopped changing. A file is only reported once its size and modification date match
    /// what they were on the previous check, so a copy or download still in progress is
    /// retried on the next check instead of being imported (and marked as handled) mid-write.
    private func scanForNewFiles() {
        guard let accessedURL else { return }
        let currentNames = Self.audioFileNames(in: accessedURL)

        // Stop tracking anything that disappeared (renamed away, deleted) before stabilizing.
        pendingFiles = pendingFiles.filter { currentNames.contains($0.key) }

        var stabilized: [String] = []
        for (name, previousSnapshot) in pendingFiles {
            guard let currentSnapshot = Self.snapshot(of: name, in: accessedURL) else {
                pendingFiles.removeValue(forKey: name)
                continue
            }
            if currentSnapshot == previousSnapshot {
                stabilized.append(name)
                pendingFiles.removeValue(forKey: name)
            } else {
                pendingFiles[name] = currentSnapshot
            }
        }

        // Start tracking anything neither handled nor already pending. Take a baseline
        // snapshot only — it needs to survive unchanged into a later check to count as stable.
        let untracked = currentNames.subtracting(knownFileNames).subtracting(pendingFiles.keys)
        for name in untracked {
            pendingFiles[name] = Self.snapshot(of: name, in: accessedURL)
        }

        for name in stabilized.sorted() {
            knownFileNames.insert(name)
            onNewFile?(accessedURL.appending(path: name))
        }

        scheduleStabilityRecheckIfNeeded()
    }

    /// Keeps polling while files are still stabilizing, since a file that's only growing in
    /// place won't produce any more directory-write events to trigger `scheduleScan` again.
    private func scheduleStabilityRecheckIfNeeded() {
        stabilityRecheck?.cancel()
        stabilityRecheck = nil
        guard !pendingFiles.isEmpty else { return }
        let workItem = DispatchWorkItem { [weak self] in self?.scanForNewFiles() }
        stabilityRecheck = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }

    private static func snapshot(of name: String, in directory: URL) -> FileSnapshot? {
        let values = try? directory.appending(path: name).resourceValues(
            forKeys: [.fileSizeKey, .contentModificationDateKey]
        )
        guard let values else { return nil }
        return FileSnapshot(size: values.fileSize ?? -1, modificationDate: values.contentModificationDate)
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
