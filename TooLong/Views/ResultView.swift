import SwiftUI

struct ResultView: View {
    @Environment(AppModel.self) private var model
    let note: VoiceNote
    let openSettings: () -> Void

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 15) {
                VStack(alignment: .leading, spacing: 15) {
                    noteHeader

                    if model.phase == .recapping {
                        HStack(spacing: 9) {
                            ProgressView().controlSize(.small)
                            Text("Getting to the point…")
                                .font(.system(.callout, design: .rounded, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .liquidPanel(
                            tint: TooLongStyle.sunshine.opacity(0.16),
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
                        Label("Another one", systemImage: "plus")
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
                    .foregroundStyle(TooLongStyle.tomato)
            }
            .frame(width: 42, height: 42)
            .glassEffect(
                .clear.tint(TooLongStyle.tomato.opacity(0.12)),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(note.fileName)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(2)
                Text(noteDetails)
                    .font(.system(.caption, design: .rounded))
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
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Spacer()
                Button {
                    model.copyRecap()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.glass)
                .help("Copy recap")
            }

            Text(recap.inShort)
                .font(.system(.body, design: .rounded))
                .textSelection(.enabled)

            if !recap.worthReplyingTo.isEmpty {
                Divider().opacity(0.55)
                VStack(alignment: .leading, spacing: 7) {
                    Text("Worth replying to")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                    ForEach(recap.worthReplyingTo, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle()
                                .fill(TooLongStyle.tomato)
                                .frame(width: 6, height: 6)
                            Text(item)
                                .font(.system(.callout, design: .rounded))
                        }
                    }
                }
            }

            Divider().opacity(0.55)

            if recap.hasSuggestedReply {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("A reply you could send")
                            .font(.system(.callout, design: .rounded, weight: .bold))
                        Spacer()
                        Button("Copy") { model.copySuggestedReply() }
                            .buttonStyle(.glass)
                            .font(.caption)
                    }
                    Text(recap.suggestedReply)
                        .font(.system(.callout, design: .rounded))
                        .italic()
                        .textSelection(.enabled)
                }
            } else {
                Button {
                    model.makeRecap(includeReplyDraft: true)
                } label: {
                    Label("Help me reply", systemImage: "arrowshape.turn.up.left")
                }
                .buttonStyle(SoftButtonStyle())
            }
        }
        .padding(16)
        .liquidPanel(tint: TooLongStyle.sunshine.opacity(0.22), cornerRadius: 22)
    }

    @ViewBuilder
    private var noRecapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.settings.provider == .none {
                Text("The transcript is ready.")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Text("Want the short version too? Add an OpenAI or Anthropic key in Settings. It's completely optional.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                Button("Set up recaps", action: openSettings)
                .buttonStyle(SoftButtonStyle())
            } else {
                Text("Want the short version?")
                    .font(.system(.headline, design: .rounded, weight: .bold))
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
                    .foregroundStyle(TooLongStyle.tomato)
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
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Spacer()
                Button("Copy") { model.copyTranscript() }
                    .buttonStyle(.glass)
                    .font(.caption)
            }

            Text(note.transcript)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.primary.opacity(0.84))
                .lineSpacing(3)
                .textSelection(.enabled)
        }
        .padding(16)
        .liquidPanel(tint: TooLongStyle.surface.opacity(0.08), cornerRadius: 20)
    }
}
