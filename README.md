# Mi Amiga

Speak English, get Spanish — then practise saying it yourself.

A small iOS app built entirely on Apple's on-device frameworks. No API keys, no
accounts, no network round-trip, and nothing you say leaves the phone.

| | |
| --- | --- |
| Speech → text | `Speech` — `SFSpeechRecognizer`, forced on-device |
| English → Spanish | `Translation` — Apple's on-device translator |
| Text → speech | `AVFoundation` — `AVSpeechSynthesizer` |
| Saved phrases | `SwiftData` — local, offline |

## What it does

**Translate.** Hold the mic, say something in English, release. The Spanish
appears; tap to hear it read aloud, or at 45% speed to pick apart a word.

**Practise.** Tap *Practise* on any phrase and say the Spanish yourself. The
recognizer switches to `es-ES` and tints each word of the target green or red by
whether you got it, and shows you what it actually heard.

**Keep phrases.** Star a translation and it lands in the library, where saved
phrases sit alongside four built-in packs — Greetings, Ordering, Asking and
Everyday. Every phrase tracks your accuracy across attempts.

The packs are written the way the phrases are actually said, not the way a
textbook puts them: `¿Me pones una caña?`, not `Yo quisiera una cerveza`. Spanish
throughout is peninsular (es-ES), matching the speech synthesis voice.

## What the practice score does and doesn't measure

It measures **whether you said the right words**. Accents and punctuation are
normalized away before comparing, so a dropped tilde doesn't read as a mistake,
and words matched out of order still count.

It is **not** a pronunciation assessment. `SFSpeechRecognizer` reports its best
guess at your words, not a phonetic analysis — so a strong accent that still
resolves to the right word scores 100%. Useful for recall and fluency; it will
not correct your accent.

## Running it

Requires **Xcode 16+** and an iPhone on **iOS 18+**.

1. `open MiAmiga/MiAmiga.xcodeproj`
2. Select the **MiAmiga** target → **Signing & Capabilities** → pick your team.
   The bundle ID is `com.sani.MiAmiga`; change it if it collides with something
   on your account.
3. Choose your iPhone and press ⌘R.

### First launch

- **Microphone** and **Speech Recognition** permissions — both required.
- **Spanish language pack** — the Translation framework presents its own system
  download sheet the first time you translate. That's Apple's UI; there's no API
  to trigger the download silently. One-time, then it works offline.

### If Xcode won't build to your device

Xcode 26 wants an ~8.5 GB iOS platform package before it will offer a physical
device as a destination. You can skip it entirely:

1. On the iPhone: **Settings → Privacy & Security → Developer Mode → On**, then
   restart. This mounts the developer disk image.
2. Build against the SDK directly and install with `devicectl`:

```bash
xcodebuild -project MiAmiga.xcodeproj -target MiAmiga \
  -sdk iphoneos -configuration Debug -allowProvisioningUpdates build

xcrun devicectl device install app \
  --device <your-device-id> build/Debug-iphoneos/MiAmiga.app
```

`xcrun devicectl list devices` gives you the device id. Note that `devicectl` is
sandboxed and may refuse paths under `~/Desktop` — copy the `.app` to `/tmp`
first if the install fails with a bookmark error.

## Notes on the build

**Better Spanish audio.** iOS ships a compact `es-ES` voice that sounds robotic.
*Settings → Accessibility → Spoken Content → Voices → Spanish* has enhanced and
premium voices; the app automatically picks the highest quality one installed, so
they take effect with no code change.

**No asset catalog.** The accent colour lives in `Views/Theme.swift`. Xcode 26's
`actool` refuses to compile an asset catalog without a simulator runtime
installed, which a device build otherwise doesn't need — so the app uses the
default iOS icon.

**Swift 5 language mode.** Swift 6's strict concurrency rejects passing a
`TranslationSession` (non-`Sendable`) into anything main-actor isolated, which is
unavoidable given how `.translationTask` vends it. The session is only ever
touched inside the translation closure, which is what the rule protects.

**On-device recognition.** `requiresOnDeviceRecognition` is set wherever the
hardware supports it. Without it `SFSpeechRecognizer` silently falls back to
Apple's servers — the wrong default for a translator used abroad on unfamiliar
wifi.

## Layout

```
MiAmiga/MiAmiga/
├── MiAmigaApp.swift              entry point; SwiftData container + pack seeding
├── Models/
│   ├── Phrase.swift              one in-session English/Spanish exchange
│   ├── SavedPhrase.swift         persisted phrase + practice stats
│   ├── PhrasePacks.swift         the four built-in starter packs
│   └── TranslatorViewModel.swift the speak → translate → speak flow
├── Services/
│   ├── SpeechRecognizer.swift    mic capture, live transcription, en/es switching
│   ├── TranslationService.swift  translation state (the session lives in the view)
│   ├── SpeechSpeaker.swift       playback + voice selection
│   └── PronunciationScorer.swift word-level scoring
└── Views/
    ├── ContentView.swift         root; hosts .translationTask
    ├── MicButton.swift           hold-to-talk with live level ring
    ├── PhraseCard.swift          the result card
    ├── PracticeView.swift        speak-along drill
    ├── LibraryView.swift         saved phrases and packs
    ├── HistoryView.swift         past translations
    └── Theme.swift               accent colour
```

## Adding another language

`TranslationService.target` is the only place Spanish is hardcoded for
translation. Swapping that `Locale.Language` moves the pipeline; you'd also want
a picker in the UI, a matching case in `SpeechRecognizer.Language`, and to
generalize the voice lookup in `SpeechSpeaker.preferredSpanishVoice()`.

## Licence

MIT — see [LICENSE](LICENSE).
