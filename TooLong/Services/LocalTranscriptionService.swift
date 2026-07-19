import AVFAudio
import CoreMedia
import Foundation
import NaturalLanguage
import Speech

enum LocalTranscriptionError: LocalizedError {
    case unavailable
    case unsupportedLanguage(String)
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "On-device transcription isn't available on this Mac."
        case .unsupportedLanguage(let language):
            "\(language) isn't available for local transcription on this Mac. Try another language in Settings."
        case .emptyTranscript:
            "No speech was found in this file. Check the language in Settings and try again."
        }
    }
}

actor LocalTranscriptionService {
    typealias ProgressHandler = @Sendable (Double) -> Void

    private struct LanguageProbe: Sendable {
        let language: TranscriptionLanguage
        let transcriber: SpeechTranscriber
    }

    private struct LanguageScore: Sendable {
        let language: TranscriptionLanguage
        let score: Double
        let characterCount: Int
    }

    func transcribe(
        fileURL: URL,
        language: TranscriptionLanguage,
        progress: @escaping ProgressHandler
    ) async throws -> TranscriptionResult {
        guard SpeechTranscriber.isAvailable else {
            throw LocalTranscriptionError.unavailable
        }

        let accessedSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        progress(0.03)
        let resolvedLanguage: TranscriptionLanguage
        if language == .automatic {
            resolvedLanguage = try await detectLanguage(in: fileURL)
            progress(0.13)
        } else {
            resolvedLanguage = language
        }

        let requestedLocale = Locale(identifier: resolvedLanguage.rawValue)
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            throw LocalTranscriptionError.unsupportedLanguage(resolvedLanguage.displayName)
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .timeIndexedTranscriptionWithAlternatives
        )

        if let installationRequest = try await AssetInventory.assetInstallationRequest(
            supporting: [transcriber]
        ) {
            progress(0.08)
            try await installationRequest.downloadAndInstall()
        }

        progress(0.15)
        let audioFile = try AVAudioFile(forReading: fileURL)
        let sampleRate = audioFile.processingFormat.sampleRate
        let duration = sampleRate > 0 ? Double(audioFile.length) / sampleRate : 0
        let analyzer = SpeechAnalyzer(
            modules: [transcriber],
            options: .init(priority: .userInitiated, modelRetention: .lingering)
        )

        let resultTask = Task<[TranscriptSegment], Error> {
            var segments: [TranscriptSegment] = []
            for try await result in transcriber.results {
                guard result.isFinal else { continue }
                let text = String(result.text.characters)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }

                let start = max(0, result.range.start.seconds)
                let end = max(start, result.range.end.seconds)
                segments.append(
                    TranscriptSegment(startTime: start, endTime: end, text: text)
                )

                if duration > 0 {
                    let speechProgress = min(1, end / duration)
                    progress(0.15 + (speechProgress * 0.83))
                }
            }
            return segments
        }

        do {
            try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)
            let segments = try await resultTask.value
            let transcript = segments.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !transcript.isEmpty else {
                throw LocalTranscriptionError.emptyTranscript
            }
            progress(1)
            return TranscriptionResult(
                duration: duration,
                transcript: transcript,
                segments: segments,
                language: resolvedLanguage
            )
        } catch {
            resultTask.cancel()
            await analyzer.cancelAndFinishNow()
            throw error
        }
    }

    private func detectLanguage(in fileURL: URL) async throws -> TranscriptionLanguage {
        let installedCodes = Set(
            await SpeechTranscriber.installedLocales.compactMap {
                $0.language.languageCode?.identifier
            }
        )
        let preferredCodes = Locale.preferredLanguages.compactMap {
            Locale(identifier: $0).language.languageCode?.identifier
        }
        let baseOrder = Dictionary(
            uniqueKeysWithValues: TranscriptionLanguage.automaticCandidates.enumerated().map {
                ($0.element.rawValue, $0.offset)
            }
        )
        let candidateLimit = max(1, AssetInventory.maximumReservedLocales)
        let candidates = TranscriptionLanguage.automaticCandidates
            .filter { language in
                guard let code = language.languageCode else { return false }
                return installedCodes.contains(code)
            }
            .sorted { first, second in
                let firstPriority = preferredCodes.firstIndex(of: first.languageCode ?? "") ?? Int.max
                let secondPriority = preferredCodes.firstIndex(of: second.languageCode ?? "") ?? Int.max
                if firstPriority != secondPriority { return firstPriority < secondPriority }
                return baseOrder[first.rawValue, default: Int.max]
                    < baseOrder[second.rawValue, default: Int.max]
            }
            .prefix(candidateLimit)

        guard let firstCandidate = candidates.first else {
            return try await fallbackLanguage()
        }
        guard candidates.count > 1 else { return firstCandidate }

        let sampleURL = try makeSampleFile(from: fileURL, maximumDuration: 28)
        defer { try? FileManager.default.removeItem(at: sampleURL) }

        var probes: [LanguageProbe] = []
        for language in candidates {
            let requestedLocale = Locale(identifier: language.rawValue)
            guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
                continue
            }

            var preset = SpeechTranscriber.Preset.timeIndexedTranscriptionWithAlternatives
            preset.attributeOptions.insert(.transcriptionConfidence)
            probes.append(
                LanguageProbe(
                    language: language,
                    transcriber: SpeechTranscriber(locale: locale, preset: preset)
                )
            )
        }

        guard let firstProbe = probes.first else { return firstCandidate }
        guard probes.count > 1 else { return firstProbe.language }

        let analyzer = SpeechAnalyzer(
            modules: probes.map(\.transcriber),
            options: .init(priority: .userInitiated, modelRetention: .whileInUse)
        )
        let scoreTasks = probes.map { probe in
            Task<LanguageScore, Error> {
                try await Self.scoreResults(for: probe)
            }
        }

        do {
            let sampleFile = try AVAudioFile(forReading: sampleURL)
            try await analyzer.start(inputAudioFile: sampleFile, finishAfterFile: true)
            let scores = try await scoreTasks.asyncMap { try await $0.value }
            return scores
                .filter { $0.characterCount > 0 }
                .max { $0.score < $1.score }?
                .language ?? firstCandidate
        } catch {
            scoreTasks.forEach { $0.cancel() }
            await analyzer.cancelAndFinishNow()
            return firstCandidate
        }
    }

    private func fallbackLanguage() async throws -> TranscriptionLanguage {
        let preferredCodes = Locale.preferredLanguages.compactMap {
            Locale(identifier: $0).language.languageCode?.identifier
        }
        if let match = preferredCodes.lazy.compactMap({ code in
            TranscriptionLanguage.automaticCandidates.first { $0.languageCode == code }
        }).first {
            return match
        }
        return .englishUS
    }

    private func makeSampleFile(
        from sourceURL: URL,
        maximumDuration: TimeInterval
    ) throws -> URL {
        let source = try AVAudioFile(forReading: sourceURL)
        let format = source.processingFormat
        let requestedFrames = AVAudioFrameCount(maximumDuration * format.sampleRate)
        let availableFrames = min(source.length, AVAudioFramePosition(AVAudioFrameCount.max))
        let frameCount = min(requestedFrames, AVAudioFrameCount(availableFrames))
        guard frameCount > 0 else { throw LocalTranscriptionError.emptyTranscript }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw LocalTranscriptionError.emptyTranscript
        }
        try source.read(into: buffer, frameCount: frameCount)

        let sampleURL = FileManager.default.temporaryDirectory
            .appending(path: "too-long-language-sample-\(UUID().uuidString).caf")
        let sample = try AVAudioFile(
            forWriting: sampleURL,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        try sample.write(from: buffer)
        return sampleURL
    }

    private nonisolated static func scoreResults(
        for probe: LanguageProbe
    ) async throws -> LanguageScore {
        var transcript = ""
        var weightedConfidence = 0.0
        var confidenceWeight = 0

        for try await result in probe.transcriber.results {
            guard result.isFinal else { continue }
            let phrase = String(result.text.characters)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty else { continue }
            transcript += transcript.isEmpty ? phrase : " \(phrase)"

            for run in result.text.runs {
                let weight = max(1, String(result.text[run.range].characters).count)
                weightedConfidence += (run.transcriptionConfidence ?? 0) * Double(weight)
                confidenceWeight += weight
            }
        }

        let confidence = confidenceWeight > 0
            ? weightedConfidence / Double(confidenceWeight)
            : 0
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(transcript)
        let languageMatches = recognizer.dominantLanguage?.rawValue == probe.language.languageCode
        let languageBoost = languageMatches ? 0.08 : 0
        let contentBoost = min(Double(transcript.count) / 120, 1) * 0.02

        return LanguageScore(
            language: probe.language,
            score: confidence + languageBoost + contentBoost,
            characterCount: transcript.count
        )
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values: [T] = []
        values.reserveCapacity(count)
        for element in self {
            values.append(try await transform(element))
        }
        return values
    }
}
