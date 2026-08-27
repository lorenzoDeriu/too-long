import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
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

        ScrollView {
            GlassEffectContainer(spacing: 20) {
                VStack(alignment: .leading, spacing: 22) {
                    settingsSection("Auto-import", icon: "tray.and.arrow.down.fill") {
                        Toggle("Watch a folder for new voice notes", isOn: autoImportBinding)

                        if settings.autoImportEnabled {
                            HStack {
                                Label(settings.autoImportFolderName ?? "Chosen folder", systemImage: "folder.fill")
                                    .font(.system(.callout, design: .rounded, weight: .semibold))
                                Spacer()
                                Button("Change folder…") { model.enableAutoImport() }
                                    .buttonStyle(SoftButtonStyle())
                            }
                            Text("New audio or video files saved here—like a voice note saved from WhatsApp or Telegram—are imported automatically.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Off by default. Turning this on asks you to choose a folder—like Downloads—so Too Long can pick up voice notes saved there without a manual drag-and-drop.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    settingsSection("Listening", icon: "waveform") {
                        Picker("Voice note language", selection: $settings.language) {
                            ForEach(TranscriptionLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        Text(settings.language == .automatic
                             ? "Too Long compares a short sample using speech languages already installed on this Mac."
                             : "Transcription happens on this Mac using Apple's speech model.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    settingsSection("In short", icon: "sparkles") {
                        Picker("Recap provider", selection: $settings.provider) {
                            ForEach(AIProvider.allCases) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }

                        if settings.provider == .none {
                            Label("Recaps are off. Voice notes are still transcribed locally.", systemImage: "checkmark.shield.fill")
                                .font(.system(.callout, design: .rounded))
                                .foregroundStyle(TooLongStyle.leaf)
                        } else {
                            VStack(alignment: .leading, spacing: 9) {
                                SecureField("\(settings.provider.displayName) API key", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)

                                HStack {
                                    Button("Save key") { saveKey() }
                                        .buttonStyle(PrimaryButtonStyle())

                                    Button(keyStatus == .testing ? "Checking…" : "Check key") {
                                        checkKey()
                                    }
                                    .buttonStyle(SoftButtonStyle())
                                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || keyStatus == .testing)

                                    Spacer()

                                    if !apiKey.isEmpty {
                                        Button("Remove", role: .destructive) { removeKey() }
                                            .buttonStyle(.plain)
                                    }
                                }

                                statusView
                            }

                            Divider()

                            Toggle("Make an In short automatically", isOn: $settings.automaticRecaps)
                            Text("When this is on and a key is saved, the recap starts after every transcription. Turn it off whenever you want everything to stay local.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Toggle("Show things worth replying to", isOn: $settings.includeReplyPoints)
                            Toggle("Draft a reply automatically", isOn: $settings.includeReplyDraft)

                            DisclosureGroup("Model") {
                                if settings.provider == .openAI {
                                    TextField("OpenAI model", text: $settings.openAIModel)
                                } else {
                                    TextField("Anthropic model", text: $settings.anthropicModel)
                                }
                            }
                        }
                    }

                    settingsSection("Privacy, plainly", icon: "hand.raised.fill") {
                        privacyRow("Your audio", detail: "Stays on this Mac")
                        privacyRow("Your transcript", detail: settings.provider == .none ? "Stays on this Mac" : "Sent only when making a recap")
                        privacyRow("Your API key", detail: "Saved in macOS Keychain")
                    }
                }
                .padding(20)
            }
        }
        .onAppear { loadKey() }
        .onChange(of: settings.provider) { _, _ in loadKey() }
    }

    private var autoImportBinding: Binding<Bool> {
        Binding(
            get: { model.settings.autoImportEnabled },
            set: { isOn in
                if isOn {
                    model.enableAutoImport()
                } else {
                    model.disableAutoImport()
                }
            }
        )
    }

    private func settingsSection<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: icon)
                .font(.system(.headline, design: .rounded, weight: .bold))
            VStack(alignment: .leading, spacing: 12, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .liquidPanel(tint: TooLongStyle.surface.opacity(0.08), cornerRadius: 20)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch keyStatus {
        case .idle:
            EmptyView()
        case .testing:
            Label("Checking with the provider…", systemImage: "ellipsis")
                .foregroundStyle(.secondary)
                .font(.caption)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(TooLongStyle.leaf)
                .font(.caption)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(TooLongStyle.tomato)
                .font(.caption)
        }
    }

    private func privacyRow(_ title: String, detail: String) -> some View {
        HStack {
            Text(title)
                .font(.system(.callout, design: .rounded, weight: .semibold))
            Spacer()
            Text(detail)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.secondary)
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
