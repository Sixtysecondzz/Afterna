# Afterna iOS

SwiftUI + SwiftData app. Shared models/networking live under `local/ConversationCore` and are compiled into the app target (XcodeGen-friendly).

## Structure

```
ios/
  project.yml
  Afterna/                         # App UI + audio + SwiftData
  local/ConversationCore/          # Models, APIClient, UploadOutbox (+ Package.swift for later SPM)
```

## Open in Xcode (macOS)

```bash
cd ios
~/bin/xcodegen generate   # or: xcodegen generate
open Afterna.xcodeproj
```

Pick an iPhone Simulator → Run.

Microphone usage string is set via generated Info.plist keys. Default upload path uses mocks (`useMockUpload: true`). Set `false` + `AFTERNA_API_BASE` when the API is reachable.
