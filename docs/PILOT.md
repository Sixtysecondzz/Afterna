# Afterna pilot — local pull & TestFlight

Two ways to test the pilot build.

## A) Pull locally (developers / Mac)

Use this when you have a Mac (or MacinCloud) and Xcode.

```bash
git clone https://github.com/Sixtysecondzz/Afterna.git
# or: cd ~/Documents/Afterna && git pull origin master

cd Afterna/ios
rm -rf Afterna.xcodeproj
~/bin/xcodegen generate   # or: xcodegen generate
open Afterna.xcodeproj
```

In Xcode:

1. Select the **Afterna** target → **Signing & Capabilities**
2. Team = your Apple Developer team (`V5GB46FZ48` if that’s still yours)
3. Bundle ID stays `app.afterna.ios`
4. Resolve Swift packages (GoogleMobileAds)
5. Plug in a **physical iPhone** (best for Apple Sign-In + mic + ads) → Run

Already wired for pilot:

| Piece | Value |
|--------|--------|
| API | `https://afterna.fly.dev` |
| Mock upload | off |
| Supabase | test project in Info.plist |
| Ads | production units |

**Guest** works without Apple; **Google** works; **Apple Sign-In** needs a real device + Team signing.

Confirm in **Settings**: API = `https://afterna.fly.dev`, Upload = Live.

---

## B) TestFlight (pilots without Xcode)

Use this so partners install from the App Store / TestFlight app.

### One-time setup (you)

1. [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **+** → New App  
   - Platform iOS  
   - Name: Afterna  
   - Bundle ID: `app.afterna.ios`  
   - SKU: e.g. `afterna-ios`
2. On Mac, in Xcode:
   - **Product → Archive**
   - **Distribute App → App Store Connect → Upload**
3. App Store Connect → your app → **TestFlight**
   - Wait for processing
   - Add **Internal Testing** group (your Apple ID) or **External** (up to 10k, needs Beta App Review once)
4. Invite testers by email → they install **TestFlight** → Accept → Install Afterna

### What pilots should verify

- [ ] Sign in with Google (Apple optional until device signing is solid)
- [ ] Record a short conversation → status progresses → transcript appears
- [ ] Credits deduct / earn via rewarded ad
- [ ] Folders, pin, to-dos, pull quote from transcript
- [ ] Ads show (banner / native / interstitial) without blocking Capture

### Backend

Fly API must stay up: `https://afterna.fly.dev/health` → `ok: true`, `fixture_mode: false`.

Worker process must be running on Fly (see `fly.toml` `[processes]` worker).

---

## Quick “pull & smoke” checklist

```bash
git pull origin master
cd ios && rm -rf Afterna.xcodeproj && xcodegen generate && open Afterna.xcodeproj
# Run on device → Google login → 30s record → wait for transcript
curl -s https://afterna.fly.dev/health
```
