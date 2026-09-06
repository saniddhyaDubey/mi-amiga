# Mi Amiga

Speak English, get Spanish. A small iOS translator built entirely on Apple's
on-device frameworks — no API keys, no accounts, no network round-trip.

| Piece | Framework |
| --- | --- |
| Speech → text | `Speech` (`SFSpeechRecognizer`, forced on-device) |
| English → Spanish | `Translation` (Apple's on-device translator) |
| Text → speech | `AVFoundation` (`AVSpeechSynthesizer`) |

## Running it

Requires **Xcode 16 or later** and an iPhone on **iOS 18+**.

1. `open MiAmiga/MiAmiga.xcodeproj`
2. Select the **MiAmiga** target → **Signing & Capabilities**, and pick your
   Apple ID under *Team*. Xcode will provision automatically.
   The bundle ID is `com.sani.MiAmiga` — change it if that collides with
   something already on your account.
3. Pick your iPhone as the run destination and hit **Run** (⌘R).

### First launch

Three prompts, in this order:

- **Microphone** and **Speech Recognition** — both required; the app explains
  itself in the dialogs and degrades to a readable error if declined.
- **Spanish language pack** — the *Translation* framework presents its own
  system download sheet the first time you translate. This is Apple's UI, not
  the app's, and there's no API to trigger the download silently. It's a
  one-time ~100 MB download, after which everything works offline.

## How to use it

Hold the mic button, say a phrase in English, release. The Spanish appears in
the card; tap **Hear it in Spanish** to play it aloud. Past phrases live behind
the clock icon in the toolbar and can be replayed or swiped away.

## Notes on the build

**No asset catalog.** The accent color lives in `Views/Theme.swift` instead.
Xcode 26's `actool` refuses to compile an asset catalog unless a simulator
runtime is installed (~8.5 GB), which this machine doesn't have room for and
which a device build otherwise doesn't need. Consequence: the app uses the
default iOS icon on your home screen. To give it a real icon, install a
simulator runtime via *Xcode → Settings → Components*, add an
`Assets.xcassets` with an `AppIcon` set, and set `ASSETCATALOG_COMPILER_APPICON_NAME`.

**Swift 5 language mode.** Swift 6's strict concurrency rejects passing a
`TranslationSession` (non-`Sendable`) into anything main-actor-isolated, which
is unavoidable given how `.translationTask` vends it. Swift 5 mode makes that a
warning. The session is still only ever touched inside the translation closure,
which is what the rule is actually protecting.

**Better Spanish audio.** iOS ships a compact `es-ES` voice by default, which
sounds robotic. *Settings → Accessibility → Spoken Content → Voices → Spanish*
has enhanced and premium voices worth downloading; the app picks the highest
quality one it finds automatically, so they take effect with no code change.

**Why hold-to-talk.** Silence-detection auto-stop kept cutting people off
mid-thought in testing patterns, and tap-to-toggle leaves the mic hot if you
forget. Holding makes the listening window unambiguous.

**On-device recognition.** `requiresOnDeviceRecognition` is set whenever the
hardware supports it, so phrases don't go to Apple's servers. Without it
`SFSpeechRecognizer` silently falls back to the network, which is the wrong
default for a translator used abroad on unfamiliar wifi.

## Layout

```
MiAmiga/MiAmiga/
├── MiAmigaApp.swift          app entry point
├── Models/
│   ├── Phrase.swift          one English/Spanish exchange
│   └── TranslatorViewModel.swift   the speak→translate→speak flow
├── Services/
│   ├── SpeechRecognizer.swift      mic capture + live transcription
│   ├── TranslationService.swift    wraps the Translation session
│   └── SpeechSpeaker.swift         Spanish playback + voice selection
└── Views/
    ├── ContentView.swift     root; hosts .translationTask
    ├── MicButton.swift       hold-to-talk button with live level ring
    ├── PhraseCard.swift      the result card
    └── HistoryView.swift     past phrases
```

## Adding more languages

`TranslationService.target` is the only place Spanish is hardcoded. Swap that
`Locale.Language` and the rest of the pipeline follows — though you'd want a
picker in the UI and a matching change to the TTS voice lookup in
`SpeechSpeaker.preferredSpanishVoice()`.
