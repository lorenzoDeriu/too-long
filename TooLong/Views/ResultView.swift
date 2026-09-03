import SwiftUI

struct ResultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let note: VoiceNote

    var body: some View {
        let t = TooLongPalette.tokens(for: colorScheme)
        ScrollView {
            GlassEffectContainer(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    noteHeader(t: t)

                    if model.phase == .recapping {
                        HStack(spacing: 9) {
                            ProgressView().controlSize(.small)
                            Text("Getting to the point…")
                                .font(TooLongFont.mono(12, weight: .medium))
                                .foregroundStyle(t.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .liquidPanel(cornerRadius: 15)
                    }

                    if let recap = note.recap {
                        recapCard(recap, t: t)
                    } else if model.phase != .recapping {
                        noRecapCard(t: t)
                    }

                    transcriptCard(t: t)

                    Button {
                        model.startOver()
                    } label: {
                        Label("Another one", systemImage: "plus")
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .font(TooLongFont.mono(12, weight: .medium))
                    .imageScale(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 70)
                .padding(.bottom, 60)
            }
        }
        .scrollIndicators(.never)
    }

    private func noteHeader(t: TooLongPalette.Tokens) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: "waveform", size: 38, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.fileName)
                    .font(TooLongFont.mono(13, weight: .medium))
                    .foregroundStyle(t.ink)
                    .lineLimit(2)
                Text(noteDetails)
                    .font(TooLongFont.mono(10, weight: .medium))
                    .foregroundStyle(t.ink3)
                    .textCase(.uppercase)
            }

            Spacer()
        }
    }

    private var noteDetails: String {
        let language = note.transcriptionLanguage?.displayName
            .replacingOccurrences(of: " (Recommended)", with: "")
        return [note.durationLabel, language, "Transcribed locally"]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func recapCard(_ recap: VoiceRecap, t: TooLongPalette.Tokens) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("In short", systemImage: "sparkles")
                    .font(TooLongFont.mono(10, weight: .semibold))
                    .foregroundStyle(TooLongPalette.accent)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    model.copyRecap()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help("Copy recap")
            }

            Text(recap.inShort)
                .font(TooLongFont.mono(13))
                .foregroundStyle(t.ink)
                .textSelection(.enabled)

            if !recap.worthReplyingTo.isEmpty {
                Divider().overlay(t.hair)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Worth replying to")
                        .font(TooLongFont.mono(10, weight: .semibold))
                        .foregroundStyle(t.ink3)
                        .textCase(.uppercase)
                    ForEach(recap.worthReplyingTo, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Circle()
                                .fill(TooLongPalette.accent)
                                .frame(width: 4, height: 4)
                            Text(item)
                                .font(TooLongFont.mono(12.5))
                                .foregroundStyle(t.ink)
                        }
                    }
                }
            }

            Divider().overlay(t.hair)

            if recap.hasSuggestedReply {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("A reply you could send")
                            .font(TooLongFont.mono(10, weight: .semibold))
                            .foregroundStyle(t.ink3)
                            .textCase(.uppercase)
                        Spacer()
                        Button {
                            model.copySuggestedReply()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .font(TooLongFont.mono(11, weight: .medium))
                        .imageScale(.small)
                    }
                    Text(recap.suggestedReply)
                        .font(TooLongFont.mono(12.5))
                        .foregroundStyle(t.ink)
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            } else {
                Button {
                    model.makeRecap(includeReplyDraft: true)
                } label: {
                    Label("Help me reply", systemImage: "arrowshape.turn.up.left")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .font(TooLongFont.mono(12, weight: .medium))
                .imageScale(.small)
            }
        }
        .padding(16)
        .liquidPanel(cornerRadius: 20)
    }

    @ViewBuilder
    private func noRecapCard(t: TooLongPalette.Tokens) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.settings.provider == .none {
                Text("The transcript is ready.")
                    .font(TooLongFont.mono(13, weight: .semibold))
                    .foregroundStyle(t.ink)
                Text("Want the short version too? Add an OpenAI or Anthropic key in Settings. It's completely optional.")
                    .font(TooLongFont.mono(12))
                    .foregroundStyle(t.ink2)
                Button {
                    model.openSettings()
                } label: {
                    Label("Set up recaps", systemImage: "gearshape")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .font(TooLongFont.mono(12, weight: .medium))
                .imageScale(.small)
            } else {
                Text("Want the short version?")
                    .font(TooLongFont.mono(13, weight: .semibold))
                    .foregroundStyle(t.ink)
                Button {
                    model.makeRecap()
                } label: {
                    Label("Give me the short version", systemImage: "sparkles")
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(TooLongPalette.accent)
                .font(TooLongFont.mono(12.5, weight: .medium))
                .imageScale(.small)
            }

            if let message = model.recapMessage {
                Text(message)
                    .font(TooLongFont.mono(11))
                    .foregroundStyle(TooLongPalette.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .liquidPanel(cornerRadius: 20)
    }

    private func transcriptCard(t: TooLongPalette.Tokens) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("What they said")
                    .font(TooLongFont.mono(10, weight: .semibold))
                    .foregroundStyle(t.ink3)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    model.copyTranscript()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .font(TooLongFont.mono(11, weight: .medium))
                .imageScale(.small)
            }

            Text(note.transcript)
                .font(TooLongFont.mono(12.5))
                .foregroundStyle(t.ink2)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
        .padding(16)
        .liquidPanel(cornerRadius: 20)
    }
}
