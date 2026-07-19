import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let provider = "aiProvider"
        static let automaticRecaps = "automaticRecaps"
        static let includeReplyPoints = "includeReplyPoints"
        static let includeReplyDraft = "includeReplyDraft"
        static let language = "transcriptionLanguage"
        static let languageSelectionVersion = "transcriptionLanguageSelectionVersion"
        static let openAIModel = "openAIModel"
        static let anthropicModel = "anthropicModel"
    }

    private let defaults: UserDefaults

    var provider: AIProvider {
        didSet { defaults.set(provider.rawValue, forKey: Key.provider) }
    }

    var automaticRecaps: Bool {
        didSet { defaults.set(automaticRecaps, forKey: Key.automaticRecaps) }
    }

    var includeReplyPoints: Bool {
        didSet { defaults.set(includeReplyPoints, forKey: Key.includeReplyPoints) }
    }

    var includeReplyDraft: Bool {
        didSet { defaults.set(includeReplyDraft, forKey: Key.includeReplyDraft) }
    }

    var language: TranscriptionLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }

    var openAIModel: String {
        didSet { defaults.set(openAIModel, forKey: Key.openAIModel) }
    }

    var anthropicModel: String {
        didSet { defaults.set(anthropicModel, forKey: Key.anthropicModel) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        provider = AIProvider(rawValue: defaults.string(forKey: Key.provider) ?? "") ?? .none
        automaticRecaps = defaults.object(forKey: Key.automaticRecaps) as? Bool ?? true
        includeReplyPoints = defaults.object(forKey: Key.includeReplyPoints) as? Bool ?? true
        includeReplyDraft = defaults.object(forKey: Key.includeReplyDraft) as? Bool ?? false
        if defaults.integer(forKey: Key.languageSelectionVersion) < 1 {
            language = .automatic
            defaults.set(TranscriptionLanguage.automatic.rawValue, forKey: Key.language)
            defaults.set(1, forKey: Key.languageSelectionVersion)
        } else {
            language = TranscriptionLanguage(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .automatic
        }
        openAIModel = defaults.string(forKey: Key.openAIModel) ?? AIProvider.openAI.defaultModel
        anthropicModel = defaults.string(forKey: Key.anthropicModel) ?? AIProvider.anthropic.defaultModel
    }

    var selectedModel: String {
        switch provider {
        case .none: ""
        case .openAI: openAIModel
        case .anthropic: anthropicModel
        }
    }
}
