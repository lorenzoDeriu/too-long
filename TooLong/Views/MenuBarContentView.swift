import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LiquidBackdrop()

            // Scrolling content sits behind the header/footer so it visibly
            // passes underneath their translucent glass as it scrolls.
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            GlassEffectContainer(spacing: 14) {
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    footer
                }
            }
        }
        .frame(width: 420, height: 620)
    }

    @ViewBuilder
    private var content: some View {
        if model.showSettings {
            SettingsView()
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else if let note = model.currentNote {
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

    private func goHome() {
        if model.showSettings {
            withAnimation(.easeInOut(duration: 0.18)) { model.closeSettings() }
        } else if model.currentNote != nil || model.phase != .idle {
            model.startOver()
        }
    }

    private func openSettings() {
        withAnimation(.easeInOut(duration: 0.18)) { model.openSettings() }
    }

    private var header: some View {
        let t = TooLongPalette.tokens(for: colorScheme)
        return HStack(spacing: 10) {
            Button(action: goHome) {
                HStack(spacing: 10) {
                    AppLogoImage(height: 19)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(model.showSettings ? "Settings" : "Too Long")
                            .font(TooLongFont.heading(15))
                            .foregroundStyle(t.ink)
                        Text(model.showSettings ? "Set up your way" : "for voice notes that got away")
                            .font(TooLongFont.mono(10.5))
                            .foregroundStyle(t.ink3)
                    }
                    .animation(nil, value: model.showSettings)
                }
            }
            .buttonStyle(.plain)

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
                        .font(.system(size: 13, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .fixedSize()
                .help("Recent voice notes")
            }

            Button(action: openSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(model.showSettings ? TooLongPalette.accent : nil)
            .help("Settings")
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .liquidPanel(cornerRadius: 18)
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private var footer: some View {
        let t = TooLongPalette.tokens(for: colorScheme)
        return HStack {
            Label("Audio stays on this Mac", systemImage: "lock.fill")
                .font(TooLongFont.mono(10, weight: .medium))
                .foregroundStyle(t.ink3)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .font(TooLongFont.mono(12, weight: .medium))
            .imageScale(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .liquidPanel(cornerRadius: 16)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

private struct EmptyStateView: View {
    let chooseFile: () -> Void
    let processFile: (URL) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDropTargeted = false

    var body: some View {
        let t = TooLongPalette.tokens(for: colorScheme)
        VStack(spacing: 22) {
            Spacer()

            VStack(spacing: 17) {
                IconBadge(systemImage: "waveform.badge.plus", size: 64, cornerRadius: 20, glass: false)

                VStack(spacing: 7) {
                    Text("Drop the long version.")
                        .font(TooLongFont.heading(22))
                        .foregroundStyle(t.ink)
                    Text("A voice note goes in.\nThe useful bits come out.")
                        .multilineTextAlignment(.center)
                        .font(TooLongFont.mono(12.5))
                        .foregroundStyle(t.ink2)
                }

                Button(action: chooseFile) {
                    Label("Choose a voice note", systemImage: "folder")
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(TooLongPalette.accent)
                .font(TooLongFont.mono(12.5, weight: .medium))
                .imageScale(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(28)
            .liquidPanel(cornerRadius: 24)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? TooLongPalette.accent.opacity(0.85) : t.dash,
                        style: StrokeStyle(lineWidth: 1, dash: [7, 7])
                    )
            }
            .frame(height: 326)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                processFile(url)
                return true
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }

            VStack(spacing: 4) {
                Label("Transcribed locally", systemImage: "apple.logo")
                    .font(TooLongFont.mono(11.5, weight: .medium))
                    .foregroundStyle(t.ink)
                Text("No account. No upload. No drama.")
                    .font(TooLongFont.mono(11))
                    .foregroundStyle(t.ink3)
            }

            Spacer()
        }
        .padding(.horizontal, 22)
    }
}

private struct ProcessingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let t = TooLongPalette.tokens(for: colorScheme)
        VStack(spacing: 22) {
            Spacer()
            IconBadge(systemImage: "waveform", size: 60, cornerRadius: 20, glass: false)

            VStack(spacing: 6) {
                Text(processingTitle)
                    .font(TooLongFont.heading(20))
                    .foregroundStyle(t.ink)
                Text(processingDetail)
                    .font(TooLongFont.mono(12.5))
                    .foregroundStyle(t.ink2)
                    .multilineTextAlignment(.center)
            }

            if model.phase == .transcribing || model.phase == .detectingLanguage {
                VStack(spacing: 7) {
                    ProgressView(value: model.progress)
                        .progressViewStyle(.linear)
                        .tint(TooLongPalette.accent)
                        .frame(width: 222)
                    Text("\(Int(model.progress * 100)) %")
                        .font(TooLongFont.mono(10, weight: .medium))
                        .foregroundStyle(t.ink3)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                model.cancelCurrentJob()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .font(TooLongFont.mono(12, weight: .medium))
            .imageScale(.small)
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidPanel(cornerRadius: 24)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let t = TooLongPalette.tokens(for: colorScheme)
        VStack(spacing: 18) {
            Spacer()
            IconBadge(systemImage: "waveform.slash", size: 60, cornerRadius: 20, glass: false)
            Text("That one didn't land.")
                .font(TooLongFont.heading(20))
                .foregroundStyle(t.ink)
            Text(model.errorMessage ?? "Try another audio file.")
                .font(TooLongFont.mono(12.5))
                .foregroundStyle(t.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
            Button {
                model.startOver()
            } label: {
                Label("Try another voice note", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(TooLongPalette.accent)
            .font(TooLongFont.mono(12.5, weight: .medium))
            .imageScale(.small)
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidPanel(cornerRadius: 24)
        .padding(24)
    }
}
