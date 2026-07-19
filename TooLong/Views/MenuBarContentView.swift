import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarContentView: View {
    @Environment(AppModel.self) private var model

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
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Choose a voice note"
        panel.prompt = "Choose Voice Note"
        panel.message = "Pick an audio or video file to transcribe locally."
        panel.allowedContentTypes = [.audio, .movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.process(fileURL: url)
    }

    private var header: some View {
        HStack(spacing: 11) {
            TinyWaveform(active: model.phase.isWorking)

            VStack(alignment: .leading, spacing: 0) {
                Text("Too Long")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                Text("for voice notes that got away")
                    .font(.system(.caption, design: .rounded))
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
                .font(.system(.caption2, design: .rounded, weight: .medium))
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
    let chooseFile: () -> Void
    let processFile: (URL) -> Void
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            VStack(spacing: 17) {
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 39, weight: .medium))
                    .foregroundStyle(TooLongStyle.tomato)
                    .padding(15)
                    .glassEffect(
                        .clear.tint(TooLongStyle.tomato.opacity(0.12)),
                        in: Circle()
                    )

                VStack(spacing: 7) {
                    Text("Drop the long version.")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("A voice note goes in.\nThe useful bits come out.")
                        .multilineTextAlignment(.center)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Button("Choose a voice note", action: chooseFile)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(28)
            .liquidPanel(
                tint: isDropTargeted ? TooLongStyle.tomato.opacity(0.20) : nil,
                cornerRadius: 34,
                interactive: true
            )
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? TooLongStyle.tomato.opacity(0.85) : .primary.opacity(0.10),
                        style: StrokeStyle(lineWidth: 1.5, dash: [7, 7])
                    )
            }
            .frame(height: 330)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                processFile(url)
                return true
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }

            VStack(spacing: 4) {
                Label("Transcribed locally", systemImage: "apple.logo")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                Text("No account. No upload. No drama.")
                    .font(.system(.caption, design: .rounded))
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
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(processingDetail)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if model.phase == .transcribing || model.phase == .detectingLanguage {
                ProgressView(value: model.progress)
                    .progressViewStyle(.linear)
                    .tint(TooLongStyle.tomato)
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
                .foregroundStyle(TooLongStyle.tomato)
            Text("That one didn't land.")
                .font(.system(size: 23, weight: .bold, design: .rounded))
            Text(model.errorMessage ?? "Try another audio file.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button("Try another voice note") { model.startOver() }
                .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding(28)
        .liquidPanel(tint: TooLongStyle.tomato.opacity(0.08), cornerRadius: 30)
        .padding(24)
    }
}
