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

First open: allow Xcode to resolve the **GoogleMobileAds** Swift package, then pick an iPhone (device preferred) → Run.

**Pilot / TestFlight:** see [`docs/PILOT.md`](../docs/PILOT.md).

### AdMob

Follows [Google Mobile Ads iOS quick start](https://developers.google.com/admob/ios/quick-start).

| Format | Production unit | Placement |
|--------|-----------------|-----------|
| App open | `…/4087246329` | Warm foreground |
| Interstitial | `…/6837798679` | After capture saved; every 5th memory open |
| Native advanced (in-feed) | set `GADNativeAdUnitID` (sample fallback) | Every 5 Memories rows |
| Banner | `…/3320959568` | Memories + Search footers |

**Capture / recording is ad-free.**

- Uses **production AdMob units** (`AdMobConfig.useTestAds = false`). Set `true` only for Google sample test IDs.
- Google Mobile Ads **12.x** (`MobileAds.shared`). On **Intel** MacinCloud, Simulator may fail (GMA 12 is arm64-only) — use a physical iPhone, or an arm64 Mac.
- After Ads SDK changes: wipe DerivedData (`rm -rf ~/Library/Developer/Xcode/DerivedData/Afterna-*`), regenerate XcodeGen, Reset/Resolve packages, Clean Build.
- App ID is set in `Afterna/Info.plist`: `ca-app-pub-9350266309525886~6797170145`.
- **Rewarded** credits: set `GADRewardedAdUnitID` in Info.plist to your unit id (`ca-app-pub-…/…`). Guests/new users get **5 credits** (1 credit = **10 min**).

### Auth (Apple + Google)

Login screen supports **Sign in with Apple** and **Continue with Google** (Supabase). Configure keys in `Afterna/Info.plist` — see [`supabase/README.md`](../supabase/README.md). Until Supabase is configured, use **Continue as Demo**.

Microphone usage string is set via Info.plist keys. Live API defaults to `https://afterna.fly.dev` with `AFTERNA_USE_MOCK_UPLOAD=false`.

### Hybrid capture (live captions + file import)

- **Record:** `StreamingMicEngine` sends 16 kHz PCM to AssemblyAI Streaming (token from `POST /v1/streaming/token`). Captions appear live; **Archive** saves the transcript and queues OpenAI extract for key points.
- **Import audio:** document picker → existing upload → async AssemblyAI → extract.
- Fixture / mock: when the API returns `fixture: true` (or `AFTERNA_USE_MOCK_UPLOAD=true`), captions and archive run without a live AssemblyAI session.
