# Too Long

**Voice notes go in. The useful bits come out.**

Too Long is an open-source, native macOS menu-bar app for everyday voice notes. Drop in an audio file, get a local transcript, and—only if you choose—turn it into a short, conversational recap using your own OpenAI or Anthropic API key.

The audio never leaves your Mac.

## How to install

> [!IMPORTANT]
> The signed Homebrew release is not live yet. Until it is available, install Too Long from source using the instructions below.

### Homebrew

Once the first signed and notarized release is published, installation will take one command:

```sh
brew install --cask lorenzoDeriu/tap/too-long
```

Homebrew will then keep Too Long current with:

```sh
brew upgrade --cask too-long
```

### Build from source

Building Too Long currently requires:

- macOS 26 or newer
- Xcode 26 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

Clone the repository and generate the Xcode project:

```sh
git clone https://github.com/lorenzoDeriu/too-long.git
cd too-long
brew install xcodegen
xcodegen generate
```

Then build and launch the app:

```sh
xcodebuild \
  -project TooLong.xcodeproj \
  -scheme TooLong \
  -configuration Debug \
  -derivedDataPath DerivedData \
  build

open "DerivedData/Build/Products/Debug/Too Long.app"
```

Alternatively, open `TooLong.xcodeproj` in Xcode and run the `TooLong` scheme. Too Long has no Dock icon; after launch, look for it in the menu bar.

The macOS 26 requirement comes from the Apple speech and Liquid Glass APIs used by the app.

## Features

- Native SwiftUI menu-bar experience with Liquid Glass
- Local transcription with Apple's `SpeechAnalyzer`
- Automatic on-device language detection
- Drag and drop or file picker for audio and video files
- Direct support for WhatsApp `.opus` voice notes
- Timestamped transcripts that can be copied in one click
- Optional **In short** recap, things **Worth replying to**, and a suggested reply
- Bring-your-own-key support for OpenAI and Anthropic
- API keys stored locally in macOS Keychain
- On-device history for the 20 most recent notes

## Privacy

Too Long works without an account, API key, or external transcription service.

| Data | What happens |
| --- | --- |
| Audio | Transcribed locally and never uploaded by Too Long |
| Transcript | Stored locally; sent to your chosen AI provider only when making a recap |
| API key | Stored in macOS Keychain and sent only to the selected provider |
| Recent notes | The latest 20 are stored in the app's local Application Support container |

If you save an API key, automatic recaps are enabled by default. You can disable them in Settings and request a recap manually, or select **No provider** to keep the entire workflow local. Use of OpenAI or Anthropic is subject to that provider's terms and data policies.

## Languages

Too Long currently supports:

- English (US and UK)
- French
- German
- Italian
- Spanish

In automatic mode, Too Long compares a short sample locally using compatible Apple speech languages installed on the Mac. If detection is unreliable, choose the language explicitly in Settings. Availability depends on the speech assets supported by the current Mac.

## Use Too Long

1. Open Too Long from the menu bar.
2. Drop a voice note into the window or click **Choose a voice note**.
3. Wait for local language detection and transcription.
4. Read or copy the timestamped transcript.
5. Optionally configure OpenAI or Anthropic in Settings to create recaps and reply suggestions.

The file picker accepts audio and movie types recognized by macOS. Actual codec support depends on AVFoundation on the installed macOS version.

## Optional AI recaps

Open Settings and select **OpenAI** or **Anthropic**, enter your own API key, and choose the model you want Too Long to use. The app validates the key before saving it.

Recaps are designed for normal conversation rather than meeting minutes. They can include:

- A short summary in the same language as the transcript
- Questions or details worth replying to
- An optional natural reply draft

You can disable automatic recaps, reply points, or reply drafts independently.

## Tests

Run the unit test suite with:

```sh
xcodebuild \
  -project TooLong.xcodeproj \
  -scheme TooLong \
  -configuration Debug \
  -derivedDataPath DerivedData \
  test
```

The real-audio integration test is opt-in so the regular test suite does not depend on a personal recording:

```sh
TOOLONG_TEST_AUDIO_PATH="/absolute/path/to/voice-note.opus" \
xcodebuild \
  -project TooLong.xcodeproj \
  -scheme TooLong \
  -configuration Debug \
  -derivedDataPath DerivedData \
  test
```

## Project structure

```text
TooLong/
├── App/          App entry point and application state
├── Models/       Settings, providers, transcripts, and recaps
├── Resources/    Sandbox entitlements
├── Services/     Transcription, AI providers, Keychain, and history
└── Views/        Menu-bar, result, and settings interfaces
```

`project.yml` is the source of truth for the generated Xcode project.

## Contributing

Issues and pull requests are welcome. Please keep the local-first privacy model intact, do not commit API keys or personal recordings, regenerate the Xcode project after changing `project.yml`, and run the test suite before submitting a change.

## License

Too Long is available under the [MIT License](LICENSE).
