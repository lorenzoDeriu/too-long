import SwiftUI

struct ResultView: View {
    @Environment(AppModel.self) private var model
    @State private var copiedTarget: CopyTarget?
    let note: VoiceNote

    private enum CopyTarget {
        case recap
        case transcript
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 15) {
                VStack(alignment: .leading, spacing: 15) {
                    noteHeader

                    if model.phase == .recapping {
                        HStack(spacing: 9) {
                            ProgressView().controlSize(.small)
                            Text("Getting to the point…")
                                .font(.callout.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .liquidPanel(
                            tint: TooLongStyle.aqua.opacity(0.10),
                            cornerRadius: 15
                        )
                    }

                    if let recap = note.recap {
                        recapCard(recap)
                    } else if model.phase != .recapping {
                        noRecapCard
                    }

                    transcriptCard

                    Button {
                        model.startOver()
                    } label: {
                        Label("Transcribe another note", systemImage: "plus")
                    }
                    .buttonStyle(SoftButtonStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                }
                .padding(16)
            }
        }
        .scrollIndicators(.never)
    }

    private var noteHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Image(systemName: "waveform")
                    .foregroundStyle(TooLongStyle.indigo)
            }
            .frame(width: 42, height: 42)
            .glassEffect(
                .clear.tint(TooLongStyle.indigo.opacity(0.12)),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(note.fileName)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text(noteDetails)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var noteDetails: String {
        let language = note.transcriptionLanguage?.displayName
            .replacingOccurrences(of: " (Recommended)", with: "")
        return [note.durationLabel, language, "transcribed locally"]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func recapCard(_ recap: VoiceRecap) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("In short", systemImage: "sparkles")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button {
                    model.copyRecap()
                    markCopied(.recap)
                } label: {
                    Image(systemName: copiedTarget == .recap ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copiedTarget == .recap ? TooLongStyle.success : Color.primary)
                }
                .buttonStyle(.glass)
                .help(copiedTarget == .recap ? "Recap copied" : "Copy recap")
                .accessibilityLabel(copiedTarget == .recap ? "Recap copied" : "Copy recap")
            }

            Text(recap.inShort)
                .font(.body)
                .textSelection(.enabled)

            if !recap.worthReplyingTo.isEmpty {
                Divider().opacity(0.55)
                VStack(alignment: .leading, spacing: 7) {
                    Text("Worth replying to")
                        .font(.callout.weight(.semibold))
                    ForEach(recap.worthReplyingTo, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle()
                                .fill(TooLongStyle.aqua)
                                .frame(width: 6, height: 6)
                            Text(item)
                                .font(.callout)
                        }
                    }
                }
            }
        }
        .padding(16)
        .liquidPanel(tint: TooLongStyle.indigo.opacity(0.12), cornerRadius: 22)
    }

    @ViewBuilder
    private var noRecapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.settings.provider == .none {
                Text("The transcript is ready.")
                    .font(.headline.weight(.semibold))
                Text("Want the short version too? Add an OpenAI or Anthropic key in Settings. It's completely optional.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                SettingsLink {
                    Text("Set up recaps")
                }
                .buttonStyle(SoftButtonStyle())
            } else {
                Text("Want the short version?")
                    .font(.headline.weight(.semibold))
                Button {
                    model.makeRecap()
                } label: {
                    Label("Give me the short version", systemImage: "sparkles")
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            if let message = model.recapMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(TooLongStyle.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .liquidPanel(cornerRadius: 20)
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("What they said")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button(copiedTarget == .transcript ? "Copied" : "Copy") {
                    model.copyTranscript()
                    markCopied(.transcript)
                }
                    .buttonStyle(.glass)
                    .font(.caption)
                    .foregroundStyle(copiedTarget == .transcript ? TooLongStyle.success : Color.primary)
            }

            Text(note.transcript)
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.84))
                .lineSpacing(3)
                .textSelection(.enabled)
        }
        .padding(16)
        .liquidPanel(tint: TooLongStyle.surface.opacity(0.08), cornerRadius: 20)
    }

    private func markCopied(_ target: CopyTarget) {
        copiedTarget = target
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            if copiedTarget == target {
                copiedTarget = nil
            }
        }
    }
}
