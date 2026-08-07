# Afterna iOS

SwiftUI + SwiftData app with shared `ConversationCore` package.

## Structure

```
ios/
  Package.swift                 # ConversationCore (models, APIClient, UploadOutbox)
  Sources/ConversationCore/
  Afterna/                      # App target sources (open on macOS with Xcode)
    AfternaApp.swift
    App/ Features/ Audio/ Core/
```

## Open in Xcode (macOS)

1. Create a new iOS App named **Afterna**, bundle id `app.afterna.ios`, SwiftUI + SwiftData.
2. Replace generated sources with `Afterna/`.
3. Add local package: File → Add Package Dependencies → Add Local → select `ios/` (ConversationCore).
4. Set `AFTERNA_API_BASE` in scheme env to `http://127.0.0.1:8787` for simulator.
5. Microphone usage description: `Afterna records conversations you choose to capture.`

Or with [XcodeGen](https://github.com/yonaskolb/XcodeGen): `cd ios && xcodegen generate`.

## Phases covered

| Phase | Status |
|-------|--------|
| 0 Foundation + ConversationCore + offline config | Done |
| 1 Nav + design tokens + tab shells | Done |
| 2 Recording engine (`AVAudioCaptureEngine`) | Done (device/sim on Mac) |
| 3 SwiftData library + detail | Done |
| 5 Upload outbox → auto-transcribe status | Done (`UploadOutbox` + Capture flow; mock by default) |

Set `AppContainer(useMockUpload: false)` to hit the real Node API.
