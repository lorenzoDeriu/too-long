import Foundation

struct TranscriptSegment: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String

    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }

    var timestamp: String {
        let totalSeconds = max(0, Int(startTime.rounded(.down)))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

struct VoiceRecap: Codable, Equatable, Sendable {
    let inShort: String
    let worthReplyingTo: [String]
}

struct VoiceNote: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let fileName: String
    let createdAt: Date
    let duration: TimeInterval
    var transcript: String
    var segments: [TranscriptSegment]
    var transcriptionLanguage: TranscriptionLanguage?
    var recap: VoiceRecap?
    var recapProvider: AIProvider?

    init(
        id: UUID = UUID(),
        fileName: String,
        createdAt: Date = .now,
        duration: TimeInterval,
        transcript: String,
        segments: [TranscriptSegment],
        transcriptionLanguage: TranscriptionLanguage? = nil,
        recap: VoiceRecap? = nil,
        recapProvider: AIProvider? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.duration = duration
        self.transcript = transcript
        self.segments = segments
        self.transcriptionLanguage = transcriptionLanguage
        self.recap = recap
        self.recapProvider = recapProvider
    }

    var durationLabel: String {
        let seconds = max(0, Int(duration.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct TranscriptionResult: Sendable {
    let duration: TimeInterval
    let transcript: String
    let segments: [TranscriptSegment]
    let language: TranscriptionLanguage
}
