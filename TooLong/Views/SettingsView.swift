import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var apiKey = ""
    @State private var keyStatus: KeyStatus = .idle

    private enum KeyStatus: Equatable {
        case idle
        case testing
        case success(String)
        case failure(String)
    }

    var body: some View {
        @Bindable var settings = model.settings
        let t = TooLongPalette.tokens(for: colorScheme)

        ScrollView {
            GlassEffectContainer(spacing: 20) {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection("Appearance", icon: "circle.righthalf.filled", t: t) {
                    Toggle("Dark mode", isOn: $settings.forceDarkMode)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(TooLongPalette.accent)
                        .font(TooLongFont.mono(12.5))
                        .foregroundStyle(t.ink)
                    Text("Off follows the system appearance. Turn it on to keep Too Long dark whatever macOS is doing.")
                        .font(TooLongFont.mono(11))
                        .foregroundStyle(t.ink3)
                }

                settingsSection("Listening", icon: "waveform", t: t) {
                    Picker("Voice note language", selection: $settings.language) {
                        ForEach(TranscriptionLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .font(TooLongFont.mono(12.5))
                    Text(settings.language == .automatic
                         ? "Too Long compares a short sample using speech languages already installed on this Mac."
                         : "Transcription happens on this Mac using Apple's speech model.")
                        .font(TooLongFont.mono(11))
                        .foregroundStyle(t.ink3)
                }

                settingsSection("In short", icon: "sparkles", t: t) {
                    Picker("Recap provider", selection: $settings.provider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .font(TooLongFont.mono(12.5))

                    if settings.provider == .none {
                        Label("Recaps are off. Voice notes are still transcribed locally.", systemImage: "checkmark.shield.fill")
                            .font(TooLongFont.mono(12))
                            .foregroundStyle(t.ink)
                    } else {
                        VStack(alignment: .leading, spacing: 9) {
                            SecureField("\(settings.provider.displayName) API key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(TooLongFont.mono(12.5))

                            HStack {
                                Button {
                                    saveKey()
                                } label: {
                                    Label("Save key", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.glassProminent)
                                .buttonBorderShape(.capsule)
                                .controlSize(.large)
                                .tint(TooLongPalette.accent)
                                .font(TooLongFont.mono(12, weight: .medium))
                                .imageScale(.small)

                                Button {
                                    checkKey()
                                } label: {
                                    Label(
                                        keyStatus == .testing ? "Checking…" : "Check key",
                                        systemImage: "checkmark.seal"
                                    )
                                }
                                .buttonStyle(.glass)
                                .buttonBorderShape(.capsule)
                                .controlSize(.large)
                                .font(TooLongFont.mono(12, weight: .medium))
                                .imageScale(.small)
                                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || keyStatus == .testing)

                                Spacer()

                                if !apiKey.isEmpty {
                                    Button(role: .destructive) {
                                        removeKey()
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                    .buttonStyle(.plain)
                                    .font(TooLongFont.mono(11.5))
                                    .imageScale(.small)
                                }
                            }

                            statusView(t: t)
                        }

                        Divider().overlay(t.hair)

                        Toggle("Make an In short automatically", isOn: $settings.automaticRecaps)
                            .toggleStyle(.switch)
                        .controlSize(.small)
                            .tint(TooLongPalette.accent)
                            .font(TooLongFont.mono(12.5))
                            .foregroundStyle(t.ink)
                        Text("When this is on and a key is saved, the recap starts after every transcription. Turn it off whenever you want everything to stay local.")
                            .font(TooLongFont.mono(11))
                            .foregroundStyle(t.ink3)

                        Toggle("Show things worth replying to", isOn: $settings.includeReplyPoints)
                            .toggleStyle(.switch)
                        .controlSize(.small)
                            .tint(TooLongPalette.accent)
                            .font(TooLongFont.mono(12.5))
                            .foregroundStyle(t.ink)
                        Toggle("Draft a reply automatically", isOn: $settings.includeReplyDraft)
                            .toggleStyle(.switch)
                        .controlSize(.small)
                            .tint(TooLongPalette.accent)
                            .font(TooLongFont.mono(12.5))
                            .foregroundStyle(t.ink)

                        Divider().overlay(t.hair)

                        DisclosureGroup("Model") {
                            if settings.provider == .openAI {
                                TextField("OpenAI model", text: $settings.openAIModel)
                                    .font(TooLongFont.mono(12))
                            } else {
                                TextField("Anthropic model", text: $settings.anthropicModel)
                                    .font(TooLongFont.mono(12))
                            }
                        }
                        .font(TooLongFont.mono(12.5))
                        .foregroundStyle(t.ink2)
                    }
                }

                settingsSection("Privacy, plainly", icon: "hand.raised.fill", t: t) {
                    privacyRow("Your audio", detail: "Stays on this Mac", t: t)
                    privacyRow("Your transcript", detail: settings.provider == .none ? "Stays on this Mac" : "Sent only when making a recap", t: t)
                    privacyRow("Your API key", detail: "Saved in macOS Keychain", t: t)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 70)
            .padding(.bottom, 60)
            }
        }
        .scrollIndicators(.never)
        .onAppear { loadKey() }
        .onChange(of: settings.provider) { _, _ in loadKey() }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        icon: String,
        t: TooLongPalette.Tokens,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(TooLongFont.mono(10, weight: .semibold))
                .foregroundStyle(t.ink3)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: 11, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(15)
                .liquidPanel(cornerRadius: 18)
        }
    }

    @ViewBuilder
    private func statusView(t: TooLongPalette.Tokens) -> some View {
        switch keyStatus {
        case .idle:
            EmptyView()
        case .testing:
            Label("Checking with the provider…", systemImage: "ellipsis")
                .foregroundStyle(t.ink3)
                .font(TooLongFont.mono(11))
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(TooLongFont.mono(11))
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(TooLongPalette.accent)
                .font(TooLongFont.mono(11))
        }
    }

    private func privacyRow(_ title: String, detail: String, t: TooLongPalette.Tokens) -> some View {
        HStack {
            Text(title)
                .font(TooLongFont.mono(12.5, weight: .medium))
                .foregroundStyle(t.ink)
            Spacer()
            Text(detail)
                .font(TooLongFont.mono(12))
                .foregroundStyle(t.ink3)
        }
    }

    private func loadKey() {
        apiKey = model.storedAPIKey(for: model.settings.provider)
        keyStatus = .idle
    }

    private func saveKey() {
        do {
            try model.saveAPIKey(apiKey, for: model.settings.provider)
            keyStatus = .success("Saved securely in Keychain.")
        } catch {
            keyStatus = .failure(error.localizedDescription)
        }
    }

    private func removeKey() {
        do {
            try model.deleteAPIKey(for: model.settings.provider)
            apiKey = ""
            keyStatus = .success("Key removed.")
        } catch {
            keyStatus = .failure(error.localizedDescription)
        }
    }

    private func checkKey() {
        let provider = model.settings.provider
        let key = apiKey
        keyStatus = .testing
        Task {
            do {
                try await model.validateAPIKey(key, for: provider)
                keyStatus = .success("Looks good.")
            } catch {
                keyStatus = .failure(error.localizedDescription)
            }
        }
    }
}
