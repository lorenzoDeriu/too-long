import Foundation

enum AIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case none
    case openAI
    case anthropic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "No provider"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        }
    }

    var keychainAccount: String {
        switch self {
        case .none: "none"
        case .openAI: "openai-api-key"
        case .anthropic: "anthropic-api-key"
        }
    }

    var defaultModel: String {
        switch self {
        case .none: ""
        case .openAI: "gpt-5.6-sol"
        case .anthropic: "claude-sonnet-5"
        }
    }
}

enum TranscriptionLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic
    case englishUS = "en-US"
    case englishUK = "en-GB"
    case german = "de-DE"
    case italian = "it-IT"
    case french = "fr-FR"
    case spanish = "es-ES"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: "Automatic (Recommended)"
        case .englishUS: "English (US)"
        case .englishUK: "English (UK)"
        case .german: "German"
        case .italian: "Italian"
        case .french: "French"
        case .spanish: "Spanish"
        }
    }

    var languageCode: String? {
        switch self {
        case .automatic: nil
        case .englishUS, .englishUK: "en"
        case .german: "de"
        case .italian: "it"
        case .french: "fr"
        case .spanish: "es"
        }
    }

    static let automaticCandidates: [TranscriptionLanguage] = [
        .englishUS,
        .italian,
        .german,
        .french,
        .spanish,
    ]
}
