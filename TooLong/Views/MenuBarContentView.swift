import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarContentView: View {
    @Environment(AppModel.self) private var model
    @State private var isChoosingFile = false
    @State private var activeOpenPanel: NSOpenPanel?

    var body: some View {
        ZStack {
            LiquidBackdrop()

            GlassEffectContainer(spacing: 14) {
                VStack(spacing: 0) {
                    header

                    Group {
                        if let note = model.currentNote {
                            ResultView(note: note)
                        } else {
                            switch model.phase {
                            case .detectingLanguage, .transcribing, .recapping:
                                ProcessingView()
                            case .failed:
                                FailureView()
                            case .idle, .ready:
                                EmptyStateView(
                                    isChoosingFile: isChoosingFile,
                                    chooseFile: chooseFile,
                                    processFile: { model.process(fileURL: $0) }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    footer
                }
            }
        }
        .frame(width: 420, height: 620)
    }

    private func chooseFile() {
        guard !isChoosingFile else { return }

        let parentWindow = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible)
        let panel = NSOpenPanel()
        panel.title = "Choose a voice note"
        panel.prompt = "Choose Voice Note"
        panel.message = "Pick an audio or video file to transcribe locally."
        panel.allowedContentTypes = [.audio, .movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        isChoosingFile = true
        activeOpenPanel = panel

        let handleSelection: (NSApplication.ModalResponse) -> Void = { response in
            isChoosingFile = false
            activeOpenPanel = nil

            if response == .OK, let url = panel.url {
                model.process(fileURL: url)
            }

            NSApp.activate(ignoringOtherApps: true)
            parentWindow?.makeKeyAndOrderFront(nil)
        }

        // MenuBarExtra uses a transient window. Attaching a sheet to it can orphan
        // the panel when macOS dismisses that window, leaving this state stuck.
        // Present the picker independently so its completion always fires.
        NSApp.activate(ignoringOtherApps: true)
        panel.begin(completionHandler: handleSelection)
        panel.makeKeyAndOrderFront(nil)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppLogoMark(width: 58)

            VStack(alignment: .leading, spacing: 2) {
                Text("Too Long")
                    .font(.system(size: 20, weight: .semibold))
                Text("Voice notes, shortened locally")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !model.recentNotes.isEmpty {
                Menu {
                    ForEach(model.recentNotes.prefix(8)) { note in
                        Button {
                            model.select(note)
                        } label: {
                            Text(note.fileName)
                            Text(note.createdAt, style: .relative)
                        }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Recent voice notes")
            }

            SettingsLink {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.glass)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .liquidPanel(tint: TooLongStyle.surface.opacity(0.10), cornerRadius: 20)
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private var footer: some View {
        HStack {
            Label("Audio stays on this Mac", systemImage: "lock.fill")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 9)
        .liquidPanel(tint: TooLongStyle.surface.opacity(0.08), cornerRadius: 16)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

private struct EmptyStateView: View {
    let isChoosingFile: Bool
    let chooseFile: () -> Void
    let processFile: (URL) -> Void
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            VStack(spacing: 17) {
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 39, weight: .medium))
                    .foregroundStyle(TooLongStyle.indigo)
                    .padding(15)
                    .glassEffect(
                        .clear.tint(TooLongStyle.indigo.opacity(0.12)),
                        in: Circle()
                    )

                VStack(spacing: 7) {
                    Text("Drop the long version.")
                        .font(.system(size: 24, weight: .semibold))
                    Text("A voice note goes in.\nThe useful bits come out.")
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Button(action: chooseFile) {
                    Label(
                        isChoosingFile ? "Choosing a file…" : "Choose a voice note",
                        systemImage: isChoosingFile ? "ellipsis" : "folder"
                    )
                }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isChoosingFile)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(28)
            .liquidPanel(
                tint: isDropTargeted ? TooLongStyle.indigo.opacity(0.18) : nil,
                cornerRadius: 34,
                interactive: true
            )
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? TooLongStyle.indigo.opacity(0.85) : .primary.opacity(0.10),
                        style: StrokeStyle(lineWidth: 1.5, dash: [7, 7])
                    )
            }
            .frame(height: 330)
            .dropDestination(for: URL.self) { urls, _ in
                guard !isChoosingFile else { return false }
                guard let url = urls.first else { return false }
                processFile(url)
                return true
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }

            VStack(spacing: 4) {
                Label("Transcribed locally", systemImage: "apple.logo")
                    .font(.callout.weight(.semibold))
                Text("No account. No upload. No drama.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct ProcessingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            TinyWaveform(active: true)
                .scaleEffect(1.7)

            VStack(spacing: 7) {
                Text(processingTitle)
                    .font(.system(size: 22, weight: .semibold))
                Text(processingDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if model.phase == .transcribing || model.phase == .detectingLanguage {
                ProgressView(value: model.progress)
                    .progressViewStyle(.linear)
                    .tint(TooLongStyle.aqua)
                    .frame(width: 230)
            } else {
                ProgressView()
                    .controlSize(.small)
            }

            Button("Stop") { model.cancelCurrentJob() }
                .buttonStyle(SoftButtonStyle())
            Spacer()
        }
        .padding(28)
        .liquidPanel(cornerRadius: 30)
        .padding(24)
    }

    private var processingTitle: String {
        switch model.phase {
        case .detectingLanguage: "Figuring out the language…"
        case .recapping: "Getting to the point…"
        default: "Listening on this Mac…"
        }
    }

    private var processingDetail: String {
        switch model.phase {
        case .detectingLanguage: "Comparing a short sample locally."
        case .recapping: "Only the transcript text is going to your chosen provider."
        default: "The audio never leaves your Mac."
        }
    }
}

private struct FailureView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "waveform.slash")
                .font(.system(size: 43))
                .foregroundStyle(TooLongStyle.danger)
            Text("That file couldn’t be transcribed.")
                .font(.system(size: 23, weight: .semibold))
            Text(model.errorMessage ?? "Try another audio file.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button("Try another voice note") { model.startOver() }
                .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding(28)
        .liquidPanel(tint: TooLongStyle.danger.opacity(0.08), cornerRadius: 30)
        .padding(24)
    }
}
