import Foundation

enum AIRecapError: LocalizedError {
    case providerMissing
    case apiKeyMissing(AIProvider)
    case invalidResponse
    case providerError(String)

    var errorDescription: String? {
        switch self {
        case .providerMissing:
            "Choose OpenAI or Anthropic in Settings first."
        case .apiKeyMissing(let provider):
            "Add your \(provider.displayName) API key in Settings first."
        case .invalidResponse:
            "The provider returned a response Too Long couldn't read. Try again."
        case .providerError(let message):
            message
        }
    }
}

actor AIRecapService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func validate(apiKey: String, provider: AIProvider) async throws {
        let url: URL
        switch provider {
        case .none:
            throw AIRecapError.providerMissing
        case .openAI:
            url = URL(string: "https://api.openai.com/v1/models")!
        case .anthropic:
            url = URL(string: "https://api.anthropic.com/v1/models")!
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthenticationHeaders(to: &request, apiKey: apiKey, provider: provider)
        let (_, response) = try await session.data(for: request)
        try validateHTTPResponse(response)
    }

    func generate(
        transcript: String,
        provider: AIProvider,
        apiKey: String,
        model: String,
        includeReplyPoints: Bool,
        includeReplyDraft: Bool
    ) async throws -> VoiceRecap {
        guard provider != .none else { throw AIRecapError.providerMissing }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIRecapError.apiKeyMissing(provider)
        }

        switch provider {
        case .none:
            throw AIRecapError.providerMissing
        case .openAI:
            return try await generateWithOpenAI(
                transcript: transcript,
                apiKey: apiKey,
                model: model,
                includeReplyPoints: includeReplyPoints,
                includeReplyDraft: includeReplyDraft
            )
        case .anthropic:
            return try await generateWithAnthropic(
                transcript: transcript,
                apiKey: apiKey,
                model: model,
                includeReplyPoints: includeReplyPoints,
                includeReplyDraft: includeReplyDraft
            )
        }
    }

    private func generateWithOpenAI(
        transcript: String,
        apiKey: String,
        model: String,
        includeReplyPoints: Bool,
        includeReplyDraft: Bool
    ) async throws -> VoiceRecap {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthenticationHeaders(to: &request, apiKey: apiKey, provider: .openAI)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "store": false,
            "instructions": instructions(
                includeReplyPoints: includeReplyPoints,
                includeReplyDraft: includeReplyDraft
            ),
            "input": transcript,
            "text": ["format": openAIStructuredOutputFormat],
        ])

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let text = decoded.output
            .flatMap(\.content)
            .first(where: { $0.type == "output_text" })?
            .text
        else {
            throw AIRecapError.invalidResponse
        }
        return try decodeRecap(from: text)
    }

    private func generateWithAnthropic(
        transcript: String,
        apiKey: String,
        model: String,
        includeReplyPoints: Bool,
        includeReplyDraft: Bool
    ) async throws -> VoiceRecap {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthenticationHeaders(to: &request, apiKey: apiKey, provider: .anthropic)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "max_tokens": 900,
            "system": instructions(
                includeReplyPoints: includeReplyPoints,
                includeReplyDraft: includeReplyDraft
            ),
            "messages": [["role": "user", "content": transcript]],
            "output_config": ["format": anthropicStructuredOutputFormat],
        ])

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw AIRecapError.invalidResponse
        }
        return try decodeRecap(from: text)
    }

    private var openAIStructuredOutputFormat: [String: Any] {
        [
            "type": "json_schema",
            "name": "voice_note_recap",
            "strict": true,
            "schema": recapSchema,
        ]
    }

    private var anthropicStructuredOutputFormat: [String: Any] {
        [
            "type": "json_schema",
            "schema": recapSchema,
        ]
    }

    private var recapSchema: [String: Any] {
        [
                "type": "object",
                "properties": [
                    "inShort": [
                        "type": "string",
                        "description": "A warm recap with the main point and useful concrete details, in the voice note's original language.",
                    ],
                    "worthReplyingTo": [
                        "type": "array",
                        "description": "Real questions, plans, or details the recipient may want to answer.",
                        "items": ["type": "string"],
                    ],
                    "suggestedReply": [
                        "type": "string",
                        "description": "A natural reply draft, or an empty string when no draft was requested.",
                    ],
                ],
                "required": ["inShort", "worthReplyingTo", "suggestedReply"],
                "additionalProperties": false,
        ]
    }

    private func instructions(includeReplyPoints: Bool, includeReplyDraft: Bool) -> String {
        """
        You help someone catch up on an everyday voice note from a friend, family member, or colleague.
        Sound warm, natural, and informal. Never turn it into meeting minutes or use corporate language.
        Stay faithful to the transcript. Do not invent facts, questions, plans, or emotions.
        Write in the same language as the transcript.

        inShort: three to five natural sentences capturing what the person actually wanted to say and the useful context around it. Include relevant specifics such as people, timing, places, reasons, or plans when they help the recipient understand the message, without turning the recap into a transcript.
        worthReplyingTo: \(includeReplyPoints ? "up to four genuine questions, plans, or details worth answering" : "always return an empty array").
        suggestedReply: \(includeReplyDraft ? "a brief, natural reply that the recipient could edit and send" : "always return an empty string").
        """
    }

    private func addAuthenticationHeaders(
        to request: inout URLRequest,
        apiKey: String,
        provider: AIProvider
    ) {
        switch provider {
        case .none:
            break
        case .openAI:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data = Data()) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIRecapError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let providerMessage = (try? JSONDecoder().decode(ProviderErrorEnvelope.self, from: data))?
                .error.message
            let fallback = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw AIRecapError.providerError(
                providerMessage ?? "The provider returned \(httpResponse.statusCode): \(fallback)."
            )
        }
    }

    private func decodeRecap(from text: String) throws -> VoiceRecap {
        guard let data = text.data(using: .utf8) else {
            throw AIRecapError.invalidResponse
        }
        do {
            return try JSONDecoder().decode(VoiceRecap.self, from: data)
        } catch {
            throw AIRecapError.invalidResponse
        }
    }
}

private struct OpenAIResponse: Decodable {
    struct OutputItem: Decodable {
        let content: [Content]
    }

    struct Content: Decodable {
        let type: String
        let text: String?
    }

    let output: [OutputItem]
}

private struct AnthropicResponse: Decodable {
    struct Content: Decodable {
        let type: String
        let text: String?
    }

    let content: [Content]
}

private struct ProviderErrorEnvelope: Decodable {
    struct ProviderError: Decodable {
        let message: String
    }

    let error: ProviderError
}
