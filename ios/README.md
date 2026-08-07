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
rm -rf Afterna.xcodeproj
~/bin/xcodegen generate
open Afterna.xcodeproj
```

First open: allow Xcode to resolve the **GoogleMobileAds** Swift package, then pick an iPhone Simulator → Run.

### AdMob

Follows [Google Mobile Ads iOS quick start](https://developers.google.com/admob/ios/quick-start).

| Format | Production unit | Placement |
|--------|-----------------|-----------|
| App open | `…/4087246329` | Warm foreground |
| Interstitial (“native interstitial”) | `…/6837798679` | After capture saved; every 5th memory open |
| Banner | `…/3320959568` | Memories + Search footers |

**Capture / recording is ad-free.**

- DEBUG builds use **Google test ad units** (`AdMobConfig.useTestAds = true`) so you don’t risk policy strikes.
- `Afterna/Info.plist` currently has Google’s **sample App ID**. Before shipping, set your real App ID (`ca-app-pub-9350266309525886~…` from AdMob → Apps → App settings) and set `useTestAds = false` for Release.

Microphone usage string is set via Info.plist keys. Default upload path uses mocks (`useMockUpload: true`).
