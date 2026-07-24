import AppKit
import Foundation
import Observation

enum WorkPhase: Equatable {
    case idle
    case detectingLanguage
    case transcribing
    case recapping
    case ready
    case failed

    var isWorking: Bool {
        self == .detectingLanguage || self == .transcribing || self == .recapping
    }
}

@MainActor
@Observable
final class AppModel {
    let settings: AppSettings

    var phase: WorkPhase = .idle
    var progress = 0.0
    var currentNote: VoiceNote?
    var recentNotes: [VoiceNote] = []
    var errorMessage: String?
    var recapMessage: String?

    @ObservationIgnored private let transcriber: LocalTranscriptionService
    @ObservationIgnored private let recapService: AIRecapService
    @ObservationIgnored private let historyStore: HistoryStore
    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private var currentJob: Task<Void, Never>?

    init(
        settings: AppSettings = AppSettings(),
        transcriber: LocalTranscriptionService = LocalTranscriptionService(),
        recapService: AIRecapService = AIRecapService(),
        historyStore: HistoryStore = HistoryStore(),
        keychain: KeychainStore = KeychainStore()
    ) {
        self.settings = settings
        self.transcriber = transcriber
        self.recapService = recapService
        self.historyStore = historyStore
        self.keychain = keychain

        Task { [weak self] in
            await self?.loadHistory()
        }
    }

    deinit {
        currentJob?.cancel()
    }

    func process(fileURL: URL) {
        currentJob?.cancel()
        phase = settings.language == .automatic ? .detectingLanguage : .transcribing
        progress = 0
        currentNote = nil
        errorMessage = nil
        recapMessage = nil

        currentJob = Task { [weak self] in
            await self?.runTranscription(fileURL: fileURL)
        }
    }

    func cancelCurrentJob() {
        currentJob?.cancel()
        currentJob = nil
        phase = currentNote == nil ? .idle : .ready
        progress = 0
    }

    func makeRecap() {
        guard currentNote != nil else { return }
        currentJob?.cancel()
        currentJob = Task { [weak self] in
            await self?.runRecap()
        }
    }

    func select(_ note: VoiceNote) {
        currentJob?.cancel()
        currentNote = note
        phase = .ready
        errorMessage = nil
        recapMessage = nil
    }

    func startOver() {
        currentJob?.cancel()
        currentNote = nil
        phase = .idle
        progress = 0
        errorMessage = nil
        recapMessage = nil
    }

    func copyTranscript() {
        guard let transcript = currentNote?.transcript else { return }
        copyToPasteboard(transcript)
    }

    func copyRecap() {
        guard let recap = currentNote?.recap else { return }
        var parts = [recap.inShort]
        if !recap.worthReplyingTo.isEmpty {
            parts.append("Worth replying to:\n" + recap.worthReplyingTo.map { "• \($0)" }.joined(separator: "\n"))
        }
        copyToPasteboard(parts.joined(separator: "\n\n"))
    }

    func storedAPIKey(for provider: AIProvider) -> String {
        (try? keychain.read(for: provider)) ?? ""
    }

    func saveAPIKey(_ value: String, for provider: AIProvider) throws {
        try keychain.save(value, for: provider)
    }

    func deleteAPIKey(for provider: AIProvider) throws {
        try keychain.delete(for: provider)
    }

    func validateAPIKey(_ value: String, for provider: AIProvider) async throws {
        try await recapService.validate(apiKey: value, provider: provider)
    }

    private func runTranscription(fileURL: URL) async {
        do {
            let result = try await transcriber.transcribe(
                fileURL: fileURL,
                language: settings.language
            ) { [weak self] value in
                Task { @MainActor [weak self] in
                    self?.progress = value
                    if value >= 0.15, self?.phase == .detectingLanguage {
                        self?.phase = .transcribing
                    }
                }
            }
            try Task.checkCancellation()

            let note = VoiceNote(
                fileName: fileURL.lastPathComponent,
                duration: result.duration,
                transcript: result.transcript,
                segments: result.segments,
                transcriptionLanguage: result.language
            )
            currentNote = note
            upsert(note)

            if settings.automaticRecaps,
               settings.provider != .none,
               !storedAPIKey(for: settings.provider).isEmpty {
                await runRecap()
            } else {
                phase = .ready
                await persistHistory()
            }
        } catch is CancellationError {
            phase = currentNote == nil ? .idle : .ready
        } catch {
            phase = .failed
            errorMessage = error.localizedDescription
        }
    }

    private func runRecap() async {
        guard var note = currentNote else { return }
        let provider = settings.provider
        phase = .recapping
        recapMessage = nil
        errorMessage = nil

        do {
            let apiKey = try keychain.read(for: provider) ?? ""
            let recap = try await recapService.generate(
                transcript: note.transcript,
                provider: provider,
                apiKey: apiKey,
                model: settings.selectedModel,
                includeReplyPoints: settings.includeReplyPoints
            )
            try Task.checkCancellation()

            note.recap = recap
            note.recapProvider = provider
            currentNote = note
            upsert(note)
            phase = .ready
            await persistHistory()
        } catch is CancellationError {
            phase = .ready
        } catch {
            phase = .ready
            recapMessage = error.localizedDescription
            await persistHistory()
        }
    }

    private func loadHistory() async {
        do {
            recentNotes = try await historyStore.load()
        } catch {
            recentNotes = []
        }
    }

    private func persistHistory() async {
        do {
            try await historyStore.save(recentNotes)
        } catch {
            recapMessage = "Your note is ready, but it couldn't be added to recent notes."
        }
    }

    private func upsert(_ note: VoiceNote) {
        recentNotes.removeAll { $0.id == note.id }
        recentNotes.insert(note, at: 0)
        recentNotes = Array(recentNotes.prefix(20))
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
