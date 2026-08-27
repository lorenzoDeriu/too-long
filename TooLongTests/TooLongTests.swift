import XCTest
@testable import Too_Long

final class VoiceNoteTests: XCTestCase {
    func testFriendlyDurationAndTimestampFormatting() {
        let note = VoiceNote(
            fileName: "voice-note.opus",
            duration: 125,
            transcript: "Hello there",
            segments: []
        )
        let segment = TranscriptSegment(startTime: 65.8, endTime: 70, text: "Hello there")

        XCTAssertEqual(note.durationLabel, "2:05")
        XCTAssertEqual(segment.timestamp, "01:05")
    }

    func testRecapKnowsWhenReplyIsPresent() {
        XCTAssertFalse(VoiceRecap(inShort: "Hi", worthReplyingTo: [], suggestedReply: "  ").hasSuggestedReply)
        XCTAssertTrue(VoiceRecap(inShort: "Hi", worthReplyingTo: [], suggestedReply: "Sounds good!").hasSuggestedReply)
    }
}

@MainActor
final class AppSettingsTests: XCTestCase {
    func testDefaultsKeepRecapsOptionalAndAutomaticAfterProviderSetup() {
        let suiteName = "TooLongTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.provider, .none)
        XCTAssertTrue(settings.automaticRecaps)
        XCTAssertTrue(settings.includeReplyPoints)
        XCTAssertFalse(settings.includeReplyDraft)
        XCTAssertEqual(settings.language, .automatic)

        settings.provider = .anthropic
        settings.automaticRecaps = false
        settings.language = .italian

        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.provider, .anthropic)
        XCTAssertFalse(restored.automaticRecaps)
        XCTAssertEqual(restored.language, .italian)
    }

    func testAutoImportIsOffByDefaultAndHasNoFolderUntilChosen() {
        let suiteName = "TooLongTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertFalse(settings.autoImportEnabled)
        XCTAssertNil(settings.autoImportFolderName)
        XCTAssertNil(settings.autoImportFolderBookmark)

        settings.autoImportEnabled = true
        settings.autoImportFolderName = "Downloads"
        settings.autoImportFolderBookmark = Data([0x01, 0x02])

        let restored = AppSettings(defaults: defaults)
        XCTAssertTrue(restored.autoImportEnabled)
        XCTAssertEqual(restored.autoImportFolderName, "Downloads")
        XCTAssertEqual(restored.autoImportFolderBookmark, Data([0x01, 0x02]))
    }
}

final class HistoryStoreTests: XCTestCase {
    func testHistoryPersistsMostRecentTwentyNotes() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "TooLongTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let fileURL = root.appending(path: "history.json")
        let store = HistoryStore(fileURL: fileURL)
        let notes = (0..<24).map { index in
            VoiceNote(
                fileName: "note-\(index).opus",
                duration: Double(index),
                transcript: "Note \(index)",
                segments: []
            )
        }

        try await store.save(notes)
        let restored = try await store.load()

        XCTAssertEqual(restored.count, 20)
        XCTAssertEqual(restored.first?.fileName, "note-0.opus")
        XCTAssertEqual(restored.last?.fileName, "note-19.opus")

        try? FileManager.default.removeItem(at: root)
    }
}

final class AutoImportServiceTests: XCTestCase {
    func testAudioFileNamesFiltersToSupportedExtensionsOnly() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "TooLongTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let names = ["note.opus", "note.OGG", "note.m4a", "note.txt", "note.pdf", ".hidden.opus"]
        for name in names {
            FileManager.default.createFile(atPath: root.appending(path: name).path, contents: Data())
        }

        let found = AutoImportService.audioFileNames(in: root)
        XCTAssertEqual(found, ["note.opus", "note.OGG", "note.m4a"])
    }
}

final class LocalTranscriptionIntegrationTests: XCTestCase {
    func testTranscribesProvidedAudioFile() async throws {
        guard let path = ProcessInfo.processInfo.environment["TOOLONG_TEST_AUDIO_PATH"] else {
            throw XCTSkip("Set TOOLONG_TEST_AUDIO_PATH to run the real-audio integration test.")
        }

        let service = LocalTranscriptionService()
        let result = try await service.transcribe(
            fileURL: URL(fileURLWithPath: path),
            language: .automatic,
            progress: { _ in }
        )

        XCTAssertGreaterThan(result.duration, 0)
        XCTAssertFalse(result.transcript.isEmpty)
        XCTAssertFalse(result.segments.isEmpty)
        XCTAssertNotEqual(result.language, .automatic)
    }
}

final class AIRecapServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testOpenAIUsesResponsesStructuredOutputAndDecodesRecap() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/responses")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")

            let body = try MockURLProtocol.bodyData(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let text = try XCTUnwrap(json["text"] as? [String: Any])
            let format = try XCTUnwrap(text["format"] as? [String: Any])
            XCTAssertEqual(format["name"] as? String, "voice_note_recap")
            XCTAssertEqual(format["strict"] as? Bool, true)
            XCTAssertEqual(json["store"] as? Bool, false)
            let instructions = try XCTUnwrap(json["instructions"] as? String)
            XCTAssertTrue(instructions.contains("three to five natural sentences"))
            XCTAssertTrue(instructions.contains("useful context around it"))

            return MockURLProtocol.response(
                for: request,
                json: #"{"output":[{"content":[{"type":"output_text","text":"{\"inShort\":\"Dinner moved to eight.\",\"worthReplyingTo\":[\"Can you make it?\"],\"suggestedReply\":\"Yep, see you then!\"}"}]}]}"#
            )
        }

        let service = AIRecapService(session: mockSession())
        let recap = try await service.generate(
            transcript: "Long transcript",
            provider: .openAI,
            apiKey: "test-key",
            model: "gpt-test",
            includeReplyPoints: true,
            includeReplyDraft: true
        )

        XCTAssertEqual(recap.inShort, "Dinner moved to eight.")
        XCTAssertEqual(recap.worthReplyingTo, ["Can you make it?"])
        XCTAssertEqual(recap.suggestedReply, "Yep, see you then!")
    }

    func testAnthropicUsesProviderSpecificStructuredOutputAndDecodesRecap() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")

            let body = try MockURLProtocol.bodyData(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let outputConfig = try XCTUnwrap(json["output_config"] as? [String: Any])
            let format = try XCTUnwrap(outputConfig["format"] as? [String: Any])
            XCTAssertNil(format["name"])
            XCTAssertNil(format["strict"])
            XCTAssertNotNil(format["schema"])
            let instructions = try XCTUnwrap(json["system"] as? String)
            XCTAssertTrue(instructions.contains("three to five natural sentences"))
            XCTAssertTrue(instructions.contains("useful context around it"))

            return MockURLProtocol.response(
                for: request,
                json: #"{"content":[{"type":"text","text":"{\"inShort\":\"Dinner moved to eight.\",\"worthReplyingTo\":[],\"suggestedReply\":\"\"}"}]}"#
            )
        }

        let service = AIRecapService(session: mockSession())
        let recap = try await service.generate(
            transcript: "Long transcript",
            provider: .anthropic,
            apiKey: "test-key",
            model: "claude-test",
            includeReplyPoints: false,
            includeReplyDraft: false
        )

        XCTAssertEqual(recap.inShort, "Dinner moved to eight.")
        XCTAssertTrue(recap.worthReplyingTo.isEmpty)
        XCTAssertFalse(recap.hasSuggestedReply)
    }

    private func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func response(for request: URLRequest, json: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(json.utf8))
    }

    static func bodyData(from request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeContentData) }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
